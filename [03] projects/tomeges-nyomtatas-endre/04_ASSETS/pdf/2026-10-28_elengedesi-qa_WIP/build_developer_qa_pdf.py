from pathlib import Path
import re, html, json, hashlib
from reportlab.pdfgen import canvas
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.pagesizes import A4
from pypdf import PdfReader

ROOT = next(p for p in Path(__file__).resolve().parents if (p / '_START-HERE.md').is_file())
PROJECT = ROOT / '[03] projects/tomeges-nyomtatas-endre'
SOURCE = PROJECT / '03_DRAFTS/2026-10-28_elengedesi-qa-fejlesztoi-szabalyok_WIP.md'
OUT = ROOT / '[04] outputs/2026-10-28_elengedesi-qa-fejlesztoi-utmutato_WIP.pdf'
OUT.parent.mkdir(parents=True, exist_ok=True)
TEXT = SOURCE.read_text(encoding='utf-8')
# The PDF groups the original numbered sections into thematic pages.
TEXT = TEXT.replace('a 6–7. fejezetben közvetlenül hivatkozva', 'a LOOP- és táblakulcs-szabálynál közvetlenül hivatkozva')
SECTIONS = {int(m.group(1)): m.group(2).strip() for m in re.finditer(r'^## (\d+)\. (.*?)(?=^## |\Z)', TEXT, re.M | re.S)}
FONTDIR = Path('C:/Windows/Fonts')
for name, filename in [('Body','calibri.ttf'),('Bold','calibrib.ttf'),('Italic','calibrii.ttf'),('Mono','consola.ttf')]:
    pdfmetrics.registerFont(TTFont(name,str(FONTDIR/filename)))
pdfmetrics.registerFontFamily('Body', normal='Body', bold='Bold', italic='Italic', boldItalic='Bold')
NAVY = colors.HexColor('#163249')
TEAL = colors.HexColor('#007F83')
INK = colors.HexColor('#233440')
MUTED = colors.HexColor('#586B78')
PALE = colors.HexColor('#EDF5F6')
LINE = colors.HexColor('#D9E3E8')
W,H = A4
MARGIN = 44
WIDTH = W-2*MARGIN
styles = {
 'body': ParagraphStyle('body',fontName='Body',fontSize=10.2,leading=14.1,textColor=INK,spaceAfter=8),
 'small': ParagraphStyle('small',fontName='Body',fontSize=8.7,leading=11.5,textColor=MUTED,spaceAfter=5),
 'h1': ParagraphStyle('h1',fontName='Bold',fontSize=24,leading=28,textColor=NAVY,spaceAfter=15),
 'h2': ParagraphStyle('h2',fontName='Bold',fontSize=16,leading=20,textColor=NAVY,spaceAfter=12,keepWithNext=True),
 'h3': ParagraphStyle('h3',fontName='Bold',fontSize=12.8,leading=16.5,textColor=TEAL,spaceBefore=5,spaceAfter=9,keepWithNext=True),
 'cell': ParagraphStyle('cell',fontName='Body',fontSize=9.1,leading=12,textColor=INK),
 'th': ParagraphStyle('th',fontName='Bold',fontSize=9.1,leading=12,textColor=colors.white),
 'list': ParagraphStyle('list',fontName='Body',fontSize=10.2,leading=14.1,textColor=INK,leftIndent=16,firstLineIndent=-16,spaceAfter=8),
}

def normalize(s):
    return s.replace('\u2013','-').replace('\u2014','-').replace('\u2011','-').replace('\u2010','-').replace('→','>').replace('…','...')

def markup(s):
    s = normalize(s)
    def link(m):
        title, target = m.group(1),m.group(2).strip('<>')
        if target.startswith('https://'):
            return f'<link href="{html.escape(target,quote=True)}" color="#007F83">{html.escape(title)}</link>'
        return html.escape(title)
    tokens=[]
    def stash(m):
        tokens.append(link(m)); return f'ZZLINKTOKEN{len(tokens)-1}ZZ'
    s=re.sub(r'\[([^\]]+)\]\((<[^>]+>|[^)]+)\)',stash,s)
    s=html.escape(s).replace('&lt;br/&gt;', '<br/>')
    s=re.sub(r'\*\*(.+?)\*\*',r'<b>\1</b>',s)
    s=re.sub(r'`([^`]+)`',r'<font name="Mono" size="9">\1</font>',s)
    for i,t in enumerate(tokens):s=s.replace(f'ZZLINKTOKEN{i}ZZ',t)
    return s

def para(s,style='body'):
    return Paragraph(markup(s),styles[style])

def table(rows,widths):
    data=[[para(cell,'th' if n==0 else 'cell') for cell in row] for n,row in enumerate(rows)]
    t=Table(data,colWidths=widths,repeatRows=1,hAlign='LEFT')
    t.setStyle(TableStyle([
      ('BACKGROUND',(0,0),(-1,0),NAVY),('VALIGN',(0,0),(-1,-1),'TOP'),
      ('LEFTPADDING',(0,0),(-1,-1),9),('RIGHTPADDING',(0,0),(-1,-1),9),
      ('TOPPADDING',(0,0),(-1,-1),7),('BOTTOMPADDING',(0,0),(-1,-1),7),
      ('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,PALE]),
      ('LINEBELOW',(0,0),(-1,0),.5,NAVY),('LINEBELOW',(0,1),(-1,-1),.35,LINE),
    ]))
    return t

def parse_section(number,heading=True):
    lines=SECTIONS[number].splitlines()
    story=[para(lines[0],'h3')] if heading else []
    i=1
    while i<len(lines):
        if not lines[i].strip():i+=1;continue
        if lines[i].startswith('|'):
            rows=[]
            while i<len(lines) and lines[i].startswith('|'):
                row=[x.strip() for x in lines[i].strip().strip('|').split('|')]
                if not all(re.fullmatch(r':?-+:?',c) for c in row):rows.append(row)
                i+=1
            if len(rows[0])==4:widths=[45,210,55,WIDTH-310]
            elif len(rows[0])==3:widths=[113,211,WIDTH-324]
            else:widths=[WIDTH*.48,WIDTH*.52]
            story.extend([table(rows,widths),Spacer(1,10)])
            continue
        line=lines[i]
        if re.match(r'^(\d+\. |- )',line):
            story.append(para(line,'list' if number==9 else 'small' if number==11 else 'body'));i+=1;continue
        chunk=[line];i+=1
        while i<len(lines) and lines[i].strip() and not lines[i].startswith('|'):
            chunk.append(lines[i]);i+=1
        story.append(para(' '.join(chunk)))
    return story

class NumberedCanvas(canvas.Canvas):
    def __init__(self,*args,**kwargs):
        canvas.Canvas.__init__(self,*args,**kwargs);self._states=[]
    def showPage(self):
        self._states.append(dict(self.__dict__));self._startPage()
    def save(self):
        total=len(self._states)
        for state in self._states:
            self.__dict__.update(state)
            self.setStrokeColor(LINE);self.setLineWidth(.5)
            self.line(MARGIN,38,W-MARGIN,38)
            self.setFont('Body',8);self.setFillColor(MUTED)
            self.drawString(MARGIN,25,'SAP ABAP | SCI / Onapsis | WIP | 2026-10-28')
            self.drawRightString(W-MARGIN,25,f'{self._pageNumber} / {total}')
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)

PAGE_TITLES={1:'GYORSINDÍTÓ',2:'BIZONYÍTÉK ÉS HATÓKÖR',3:'ADATFÜGGŐSÉGEK ÉS ÜZENETEK',4:'VEZÉRLÉS ÉS CIKLUSOK',5:'TÁBLÁK ÉS ADATELÉRÉS',6:'ELLENŐRZÉSI MENET',7:'FORRÁSOK ÉS ELKÉSZÜLTSÉG'}
def page_header(c,doc):
    c.setFillColor(TEAL);c.rect(0,H-10,W,10,fill=1,stroke=0)
    c.setFont('Bold',8);c.setFillColor(MUTED)
    c.drawString(MARGIN,H-33,'FEJLESZTŐI ÚTMUTATÓ')
    c.drawRightString(W-MARGIN,H-33,PAGE_TITLES.get(doc.page,'SCI / ONAPSIS'))

story=[]
story.append(para('Transzportkérelem<br/>QA-ellenőrzése','h1'))
story.append(para('SCI / Onapsis - fejlesztői szabályok és futtatási útmutató','h3'))
story.append(para('**Példakérelem:** DHCK906030  |  **Variáns:** Z_CONTROL_FOR_CODE','small'))
story.append(Spacer(1,4))
story.append(para('A dokumentum a korábbi helyi SCI/Onapsis-összesítés öt ismert szabályát magyarázza el. A javítási elvek mellett megadja a review és az újraellenőrzés szempontjait.'))
callout=Table([[para('**Érvényesség:** a tényleges elengedési kapu konfigurációja és teljes eredménye nincs igazolva. A leírás WIP; az SCI-futás előellenőrzésként használható.','body')]],colWidths=[WIDTH])
callout.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),PALE),('BOX',(0,0),(-1,-1),.7,LINE),('LEFTPADDING',(0,0),(-1,-1),12),('RIGHTPADDING',(0,0),(-1,-1),12),('TOPPADDING',(0,0),(-1,-1),10),('BOTTOMPADDING',(0,0),(-1,-1),3)]))
story.extend([callout,Spacer(1,14)])
story.append(para('Futtatás: SCI tranzakció','h3'))
for line in [
 '1. Aktiválásra jogosult fejlesztőként gondoskodj a vizsgálandó objektumok aktív állapotáról; az inaktív módosítás külön ellenőrzést igényel.',
 '2. Az SCI tranzakcióban hozz létre saját inspekciót, például Z_QA_ELOELLENORZES néven.',
 '3. Objektumkiválasztás: **Kérelem/feladat > DHCK906030**. Ellenőrzési variáns: **Z_CONTROL_FOR_CODE**. Ha nem látszik, ellenőrizd a helyi/globális nézetet.',
 '4. **Mentés > Végrehajtás (F8) > Eredmények**. Javítás után készíts új inspekcióverziót azonos kérelemmel és variánssal.',
]:story.append(para(line,'list'))
story.append(para('Ehhez a dokumentált előellenőrzéshez az SCI kezelőfelülete használható. Az elengedéskor induló külön riport vagy egyedi bekötés neve még nincs azonosítva. Részletes háttér: [F1].','small'))
story.append(Spacer(1,7))
overview=[['Kód','Fő fejlesztői teendő','Korábbi jelzés'],['0317','Tedd láthatóvá a globális állapot módosítását.','128 figyelm.'],['0245','Az állandó felhasználói szöveg legyen fordítható.','19 figyelm.'],['0068','Kezeld tudatosan a CASE további értékeit.','8 figyelm.'],['0089','Vizsgáld meg a sormásolás szükségességét.','7 figyelm.'],['0079','A kereséshez illő táblakulcsot használj.','6 figyelm.']]
story.append(table(overview,[45,WIDTH-145,100]))
story.append(Spacer(1,7))
story.append(para('**Korábbi futás:** 0 hiba, 209 figyelmeztetés, 141 információ. Az öt ismert szabály 168 figyelmeztetést fed le; 41 figyelmeztetés és 141 információ részletei hiányoznak.','small'))

story.append(PageBreak())
story.append(para('Mit tudunk az ellenőrzésről?','h2'))
story.extend(parse_section(1,False))
story.append(para('Az ismert szabályok eredete','h3'))
section2=parse_section(2,False)
# Preserve the official names on the evidence page in a compact, readable list.
for code,title in [('0317','Modification of Global Variables in Subroutine'),('0245','Hard-Coded Text in MESSAGE ... WITH'),('0068','Incomplete CASE'),('0089','Usage of LOOP AT itab INTO'),('0079',"Low Performance Table Access on 'Standard' Tables")]:
    story.append(para(f'**{code}** - {title}','small'))
story.append(para(SECTIONS[2].split('\n\n')[-1],'small'))

for title,nums in [('Állapot és fordítható üzenetek',[3,4]),('Esetkezelés és ciklusok',[5,6]),('Belső táblák és adatbázis-hozzáférés',[7,8]),('Javítás, ellenőrzés és igazolás',[9,10]),('Források és elkészültség',[11])]:
    story.append(PageBreak());story.append(para(title,'h2'))
    for n in nums:story.extend(parse_section(n,False if n==11 else True));story.append(Spacer(1,7))

doc=SimpleDocTemplate(str(OUT),pagesize=A4,rightMargin=MARGIN,leftMargin=MARGIN,topMargin=57,bottomMargin=52,title='Transzportkérelem QA-ellenőrzése - fejlesztői útmutató',author='SAP ABAP fejlesztés',subject='SCI / Onapsis előellenőrzés, DHCK906030, WIP',pageCompression=1)
doc.build(story,onFirstPage=page_header,onLaterPages=page_header,canvasmaker=NumberedCanvas)
reader=PdfReader(OUT)
pages=[page.extract_text() or '' for page in reader.pages]
assert len(pages)==7, f'Unexpected page count: {len(pages)}'
alltext='\n'.join(pages)
for token in ['0317','0245','0068','0089','0079','DHCK906030','Z_CONTROL_FOR_CODE','EACCES','141','209','168','41','ellenőrzés','mezőszimbólum']:
    assert token in alltext, f'Missing text: {token}'
assert '\ufffd' not in alltext
assert '<br/>' not in alltext
audit={'pages':len(pages),'page_text_lengths':[len(t) for t in pages],'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'output':str(OUT),'pdf_sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),'text_checks':'PASS','visual_review':'PENDING'}
(Path(__file__).resolve().parent/'2026-10-28_pdf-validation_WIP.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'output':str(OUT),'pages':len(pages),'page_text_lengths':audit['page_text_lengths']},ensure_ascii=False))
