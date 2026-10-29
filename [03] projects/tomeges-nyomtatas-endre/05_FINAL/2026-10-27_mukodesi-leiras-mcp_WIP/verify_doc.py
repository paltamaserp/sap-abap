from pathlib import Path
from zipfile import ZipFile
from lxml import etree
import re,json,hashlib

task=Path(__file__).resolve().parent
docx=task/'2026-10-27_tomeges-nyomtatas-mukodesi-technikai-leiras_WIP.docx'
ns={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
with ZipFile(docx) as z:
    assert z.testzip() is None
    root=etree.fromstring(z.read('word/document.xml'))
txt='\n'.join(root.xpath('//w:t/text()',namespaces=ns))
assert '\ufffd' not in txt
assert 'A tartalomjegyzék a dokumentum megnyitásakor frissíthető.' not in txt
anchors=root.xpath('//w:hyperlink/@w:anchor',namespaces=ns)
bookmarks=root.xpath('//w:bookmarkStart/@w:name',namespaces=ns)
assert len(anchors)==19 and set(anchors)<=set(bookmarks)
assert len(root.xpath('//w:tbl',namespaces=ns))==16
refs=set(re.findall(r'\[(F\d\d|M\d\d)\]',txt))
defined={f'F{x:02}' for x in range(1,25)}|{f'M{x:02}' for x in range(1,9)}
assert refs<=defined
source_root=task.parent.parent/'01_SOURCES/2026-10-27_mukodesi-leiras-mcp_WIP'
manifest=json.loads((source_root/'2026-10-27_mcp-manifest_WIP.json').read_text(encoding='utf-8'))
for item in manifest['objects']:
    for filename,digest in [('raw_file','raw_sha256'),('extracted_file','extracted_sha256')]:
        p=source_root/item[filename]
        assert hashlib.sha256(p.read_bytes()).hexdigest()==item[digest]
baseline=task.parent.parent/'05_FINAL/abap-2026-10-26'
for filename in set(re.findall(r'\b([A-Z][A-Z0-9_]+\.(?:abap|table|structure|ttyp\.json))',txt)):
    assert (baseline/filename).exists() or (source_root/filename).exists(),filename
result={'docx_zip':'valid','chapters':19,'clickable_toc_entries':len(anchors),'tables':16,
        'source_references':'all defined','new_mcp_responses_saved':len(manifest['objects']),
        'new_mcp_hashes':'all match','unicode_replacement_characters':0,
        'preview_engine':'local OOXML subset renderer and canonical render_docx.py PNG pipeline',
        'preview_pages':22,'preview_images_visually_reviewed':22,
        'native_word_pagination_verified':False,
        'native_preview_limitation':'Bundled LibreOffice unavailable; Word COM stalled and Computer Use app approval timed out. Task-owned preview processes stopped.'}
(task/'qa/2026-10-27_ellenorzes_WIP.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
