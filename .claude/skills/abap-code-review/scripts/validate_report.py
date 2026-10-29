"""Validate normalized SAP-check evidence; does not connect to SAP."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re

GATES = ('syntax', 'active_readback', 'unit', 'qa')
LABELS = dict(syntax='Szintaxis', active_readback='Aktív forrás', unit='ABAP Unit', qa='QA')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def evaluate(report, directory):
    if not isinstance(report, dict) or not isinstance(report.get('objects'), list) or not report['objects']:
        raise ValueError('Nem üres objects lista szükséges.')
    directory = Path(directory).resolve()
    results = []
    seen = set()

    def local_file(name):
        if not isinstance(name, str) or not name:
            raise ValueError('Hiányzó bizonyítékfájlnév.')
        p = (directory / name).resolve()
        if not p.is_relative_to(directory):
            raise ValueError('A bizonyíték a jelentés könyvtárán kívülre mutat.')
        return p

    def number(check, key):
        value = check.get(key)
        if type(value) is not int or value < 0:
            raise ValueError(f'Hiányzó vagy érvénytelen számláló: {key}')
        return value

    for obj in report['objects']:
        if not isinstance(obj, dict) or not obj.get('name') or not obj.get('type'):
            raise ValueError('Objektumnév és típus szükséges.')
        identity = (obj.get('system'), obj.get('client'), obj['type'], obj['name'])
        if identity in seen:
            raise ValueError('Ismétlődő objektum a jelentésben.')
        seen.add(identity)
        fingerprint = obj.get('source_sha256') or ''
        scope_ok = bool(obj.get('system') and obj.get('client') and
                        isinstance(fingerprint, str) and re.fullmatch(r'[a-fA-F0-9]{64}', fingerprint))
        checks = obj.get('checks', {})
        gates = []
        for gate in GATES:
            check = checks.get(gate, {})
            state, reason = 'RÉSZLEGES', 'Nem futott vagy nincs teljes bizonyíték.'
            status = check.get('status', 'not_run')
            if status == 'failed':
                state, reason = 'HIBÁS', check.get('reason', 'Sikertelen vizsgálat.')
            elif status == 'not_applicable':
                if gate == 'unit' and check.get('reason'):
                    state, reason = 'NEM ALKALMAZHATÓ', check['reason']
                else:
                    reason = 'Csak az Unit-lépés hagyható el, konkrét szakmai indokkal.'
            elif status == 'not_run':
                reason = check.get('reason', reason)
            elif status != 'passed':
                state, reason = 'HIBÁS', 'Ismeretlen ellenőrzési állapot.'
            elif not scope_ok or check.get('source_sha256') != fingerprint:
                reason = 'A rendszer/mandant vagy az utolsó forrásverzióhoz kötés hiányos.'
            elif not check.get('evidence'):
                reason = 'Nincs mentett bizonyíték.'
            else:
                try:
                    for evidence in check['evidence']:
                        if digest(local_file(evidence['file'])) != evidence['sha256']:
                            raise ValueError('Eltérő bizonyítékhash.')
                    if not check.get('checked_at'):
                        raise ValueError('Hiányzó vizsgálati időpont.')
                    stamp = datetime.fromisoformat(check['checked_at'].replace('Z', '+00:00'))
                    if stamp.tzinfo is None:
                        raise ValueError('A vizsgálati időpontból hiányzik az időzóna.')
                    if gate == 'syntax':
                        if number(check, 'errors'):
                            raise ValueError('A szintaxisválasz hibát tartalmaz.')
                        warnings = number(check, 'warnings')
                        if number(check, 'unresolved_warnings'):
                            raise LookupError('Kezeletlen szintaxisfigyelmeztetés.')
                        if warnings and not check.get('warning_disposition'):
                            raise LookupError('Hiányzó figyelmeztetésértékelés.')
                        if check.get('checked_version') not in ('active', 'inactive', 'source'):
                            raise LookupError('Nem igazolt a vizsgált verzió.')
                    elif gate == 'active_readback':
                        if check.get('version') != 'active':
                            raise LookupError('Nincs aktív visszaolvasás.')
                        if digest(local_file(check['expected_file'])) != fingerprint:
                            raise ValueError('A szándékolt forrás eltér az objektum ujjlenyomatától.')
                        if digest(local_file(check['actual_file'])) != fingerprint:
                            raise ValueError('A visszaolvasott forrás eltér a szándékolttól.')
                    elif gate == 'unit':
                        if check.get('completed') is not True or not check.get('run_id'):
                            raise LookupError('Nincs befejezett, azonosított Unit-futás.')
                        if number(check, 'tests') == 0:
                            raise LookupError('Nulla teszt nem sikeres Unit-ellenőrzés.')
                        if number(check, 'failures') or number(check, 'errors'):
                            raise ValueError('Bukó vagy technikai hibás Unit-teszt.')
                        if number(check, 'skipped'):
                            raise LookupError('Kihagyott Unit-tesztek maradtak.')
                    elif gate == 'qa':
                        if str(check.get('tool', '')).rsplit('__', 1)[-1].lower().startswith('check'):
                            raise ValueError('Check* szintaxisvizsgálat nem jelenthető teljes QA-ként.')
                        if check.get('completed') is not True:
                            raise LookupError('Nincs befejezett QA-futás.')
                        if not all(check.get(k) for k in ('variant', 'run_id', 'checking_system', 'tool')):
                            raise LookupError('A QA-futtató, variáns vagy futásazonosító hiányzik.')
                        if number(check, 'blocking_findings'):
                            raise ValueError('Blokkoló QA-találat maradt.')
                        if number(check, 'unresolved_findings'):
                            raise LookupError('Kezeletlen QA-találat maradt.')
                    state, reason = 'SIKERES', 'A rögzített sikerfeltételek és bizonyítékok rendben.'
                except LookupError as error:
                    reason = str(error)
                except (ValueError, OSError, KeyError, TypeError) as error:
                    state, reason = 'HIBÁS', str(error)
            gates.append(dict(check=gate, label=LABELS[gate], result=state, reason=reason))
        states = [g['result'] for g in gates]
        outcome = 'HIBÁS' if 'HIBÁS' in states else 'RÉSZLEGES' if 'RÉSZLEGES' in states or not scope_ok else 'SIKERES'
        results.append(dict(name=obj['name'], type=obj['type'], system=obj.get('system'),
                            client=obj.get('client'), result=outcome, checks=gates))
    states = [o['result'] for o in results]
    outcome = 'HIBÁS' if 'HIBÁS' in states else 'RÉSZLEGES' if 'RÉSZLEGES' in states else 'SIKERES'
    return dict(result=outcome, evaluated_at=datetime.now(timezone.utc).isoformat(), objects=results,
                scope='Mentett normalizált eredmények ellenőrzése; nem új SAP-futtatás.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    args = parser.parse_args()
    try:
        result = evaluate(json.loads(args.report.read_text(encoding='utf-8-sig')), args.report.parent)
    except (ValueError, OSError, TypeError, AttributeError) as error:
        result = dict(result='HIBÁS', reason=str(error), objects=[])
    output = args.report.with_name(args.report.stem.removesuffix('_WIP') + '_eredmeny_WIP.json')
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f"Összesítés: {result['result']}")
    for obj in result['objects']:
        print(f"{obj['name']}: {obj['result']}")
        for check in obj['checks']:
            print(f"  {check['label']}: {check['result']} — {check['reason']}")
    print(f'Jelentés: {output}')
    return {'SIKERES': 0, 'RÉSZLEGES': 2, 'HIBÁS': 1}[result['result']]


if __name__ == '__main__':
    raise SystemExit(main())
