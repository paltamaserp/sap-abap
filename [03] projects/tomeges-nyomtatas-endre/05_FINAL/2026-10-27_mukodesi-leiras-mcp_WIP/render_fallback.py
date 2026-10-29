"""Local OOXML preview for this document. Not a Word pagination certificate."""
from pathlib import Path
import sys, importlib.util, json, re, html
from docx import Document
from docx.oxml.ns import qn
from docx.table import Table as DocxTable
from docx.text.paragraph import Paragraph as DocxParagraph
from reportlab.pdfgen.canvas import Canvas
from reportlab.platypus import SimpleDocTemplate, Paragraph, Table, TableStyle, PageBreak, Spacer, KeepTogether
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.colors import HexColor, white
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.enums import TA_LEFT

TASK=Path(__file__).resolve().parent
DOCX=TASK/'2026-10-27_tomeges-nyomtatas-mukodesi-technikai-leiras_WIP.docx'
QA=TASK/'qa'; QA.mkdir(exist_ok=True)
for name,file in [('Arial','arial.ttf'),('ArialBold','arialbd.ttf')]:
    pdfmetrics.registerFont(TTFont(name,str(Path('C:/Windows/Fonts')/file)))
S={
 'Normal':ParagraphStyle('Normal',fontName='Arial',fontSize=10,leading=12,spaceAfter=7,allowWidows=0,allowOrphans=0),
 'Title':ParagraphStyle('Title',fontName='Arial',fontSize=28,leading=33,spaceAfter=18),
 'Subtitle':ParagraphStyle('Subtitle',fontName='Arial',fontSize=15,leading=18,spaceAfter=12,textColor=HexColor('#445566')),
 'Heading 1':ParagraphStyle('Heading 1',fontName='ArialBold',fontSize=19,leading=23,spaceAfter=13,textColor=HexColor('#24445E'),keepWithNext=True),
 'Heading 2':ParagraphStyle('Heading 2',fontName='ArialBold',fontSize=12,leading=14,spaceBefore=12,spaceAfter=6,textColor=HexColor('#24445E'),keepWithNext=True),
 'Cell':ParagraphStyle('Cell',fontName='Arial',fontSize=9,leading=10.5,spaceBefore=2,spaceAfter=2,splitLongWords=True),
 'CellHead':ParagraphStyle('CellHead',fontName='ArialBold',fontSize=9,leading=10.5,textColor=white),
 'Source':ParagraphStyle('Source',fontName='Arial',fontSize=8.5,leading=10.2,spaceBefore=6,spaceAfter=7,textColor=HexColor('#596777')),
 'Toc':ParagraphStyle('Toc',fontName='Arial',fontSize=10,leading=12,spaceAfter=9,textColor=HexColor('#24445E')),
}

def alltext(element):
    return ''.join(element.itertext()) if False else ''.join(n.text or '' for n in element.iter(qn('w:t')))

def safe(t): return html.escape(t).replace('\n','<br/>')

doc=Document(DOCX)
sec=doc.sections[0]
pt=lambda x:x/12700
story=[]
for el in doc.element.body:
    if el.tag==qn('w:p'):
        p=DocxParagraph(el,doc); txt=alltext(el)
        if any(x.get(qn('w:type'))=='page' for x in el.iter(qn('w:br'))): story.append(PageBreak())
        if not txt: continue
        style=p.style.name
        if style=='Heading 1': story.append(PageBreak())
        key=style if style in S else 'Normal'
        if txt.startswith('Forrás'): key='Source'
        if any(True for _ in el.iter(qn('w:hyperlink'))): key='Toc'
        story.append(Paragraph(safe(txt),S[key]))
    elif el.tag==qn('w:tbl'):
        t=DocxTable(el,doc)
        vals=[]
        for i,row in enumerate(t.rows):
            vals.append([Paragraph(safe(c.text),S['CellHead' if i==0 else 'Cell']) for c in row.cells])
        widths=[pt(c.width) for c in t.columns]
        table=Table(vals,colWidths=widths,repeatRows=1,hAlign='CENTER')
        commands=[('BACKGROUND',(0,0),(-1,0),HexColor('#24445E')),('VALIGN',(0,0),(-1,-1),'MIDDLE'),('LEFTPADDING',(0,0),(-1,-1),3.75),('RIGHTPADDING',(0,0),(-1,-1),3.75),('TOPPADDING',(0,0),(-1,-1),5),('BOTTOMPADDING',(0,0),(-1,-1),5)]
        for ri in range(2,len(vals),2): commands.append(('BACKGROUND',(0,ri),(-1,ri),HexColor('#F0F4F7')))
        table.setStyle(TableStyle(commands)); story += [table, Spacer(1,6)]

class PageCanvas(Canvas):
    def __init__(self,*a,**kw): super().__init__(*a,**kw); self.states=[]
    def showPage(self): self.states.append(dict(self.__dict__)); self._startPage()
    def save(self):
        total=len(self.states)
        for state in self.states:
            self.__dict__.update(state)
            self.setFont('Arial',8); self.setFillColor(HexColor('#667788'))
            self.drawRightString(pt(sec.page_width-sec.right_margin),23,'Tömeges nyomtatás  |  %s / %s' % (self._pageNumber,total))
            super().showPage()
        super().save()

pdf=QA/'ooxml-preview.pdf'
pdfdoc=SimpleDocTemplate(str(pdf),pagesize=(pt(sec.page_width),pt(sec.page_height)),leftMargin=pt(sec.left_margin),rightMargin=pt(sec.right_margin),topMargin=pt(sec.top_margin),bottomMargin=pt(sec.bottom_margin))
pdfdoc.build(story,canvasmaker=PageCanvas)

# Reuse the canonical rasterization pipeline with the locally rendered PDF.
skill=Path('C:/Users/T13214/.codex/plugins/cache/openai-primary-runtime/documents/26.1025.11240/skills/documents/render_docx.py')
spec=importlib.util.spec_from_file_location('canonical_docx_renderer',skill)
renderer=importlib.util.module_from_spec(spec); spec.loader.exec_module(renderer)
renderer.convert_to_pdf=lambda *args,**kwargs:(str(pdf),'Local OOXML subset renderer; Word pagination not verified')
sys.argv=[str(skill),str(DOCX),'--output_dir',str(QA),'--dpi','100']
renderer.main()
from pypdf import PdfReader
reader=PdfReader(str(pdf))
pages=[{'page':i+1,'characters':len(p.extract_text()),'text':p.extract_text()} for i,p in enumerate(reader.pages)]
(QA/'pages.json').write_text(json.dumps(pages,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'pages':len(pages),'engine':'local OOXML subset renderer with canonical PNG rasterizer','word_pagination_verified':False},ensure_ascii=False))
