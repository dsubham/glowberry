import {PDFDocument,rgb} from 'pdf-lib';
import fontkit from '@pdf-lib/fontkit';
import {deliverPdf} from './report-pdf';
import type {SchoolDocument} from './workflows-data';

type Row={date?:string;day?:string;time?:string;activity?:string;title?:string;details?:string;name?:string;grade?:string|number};
const berry=rgb(.45,.08,.20),ink=rgb(.18,.22,.18),green=rgb(.35,.48,.30);
export async function buildSchoolPdf(doc:SchoolDocument,studentName=''):Promise<Blob>{
 const pdf=await PDFDocument.create();pdf.registerFontkit(fontkit);const response=await fetch('/brand/NotoSans-Regular.ttf');if(!response.ok)throw new Error('Report font unavailable.');const font=await pdf.embedFont(await response.arrayBuffer(),{subset:true});const logoResponse=await fetch('/brand/glowberry-logo.jpg');if(!logoResponse.ok)throw new Error('Glowberry logo unavailable.');const logo=await pdf.embedJpg(await logoResponse.arrayBuffer());
 let page=pdf.addPage([595.28,841.89]),y=730,pageNo=1;
 function header(){page.drawImage(logo,{x:45,y:750,width:58,height:58});page.drawText('GLOWBERRY UTOPIA',{x:114,y:782,size:11,font,color:berry});page.drawText('Preschool & Daycare',{x:114,y:766,size:8,font,color:green});page.drawLine({start:{x:45,y:744},end:{x:550,y:744},thickness:.7,color:green});}
 function pageFooter(){page.drawLine({start:{x:45,y:46},end:{x:550,y:46},thickness:.6,color:green});page.drawText('Glowberry Utopia Preschool & Daycare',{x:45,y:30,size:8,font,color:green});page.drawText(String(pageNo),{x:540,y:30,size:8,font,color:green});}
 function room(h:number){if(y-h<75){pageFooter();page=pdf.addPage([595.28,841.89]);pageNo++;y=730;header();}}
 function line(text:string,size=10,color=ink){const max=500;let current='';for(const word of text.split(/\s+/)){const trial=current?`${current} ${word}`:word;if(font.widthOfTextAtSize(trial,size)>max&&current){room(size+7);page.drawText(current,{x:45,y,size,font,color});y-=size+7;current=word;}else current=trial;}room(size+7);if(current)page.drawText(current,{x:45,y,size,font,color});y-=size+7;}
 function heading(text:string){room(40);y-=12;line(text.toUpperCase(),10,berry);y-=5;}
 function separator(){room(20);page.drawLine({start:{x:45,y},end:{x:550,y},thickness:.7,color:green});y-=20;}
 header();line(doc.title,20,berry);if(studentName)line(`Student: ${studentName}`,11);separator();
 if(doc.kind==='calendar'){heading('Academic calendar');for(const event of (doc.data.events as Row[]||[]).sort((a,b)=>(a.date||'').localeCompare(b.date||''))){room(52);line(`${event.date||''}  ${event.title||''}`,11,berry);if(event.details)line(event.details,9);separator();}}
 if(doc.kind==='timetable'){line(`Class: ${String(doc.data.class_name||'')}`,11);heading('Weekly timetable');for(const row of doc.data.rows as Row[]||[]){room(42);line(`${row.day||''}   ${row.time||''}   ${row.activity||''}`,10);separator();}}
 if(doc.kind==='admission'){line(String(doc.data.instructions||''),10);heading('Child and family details');for(const field of doc.data.fields as string[]||[]){room(52);line(field,10,berry);page.drawLine({start:{x:45,y:y-12},end:{x:550,y:y-12},thickness:.5,color:green});y-=40;}room(70);line('Parent / guardian signature: ______________________________',9);line('Date: ______________________________',9);}
 if(doc.kind==='marksheet'){line(`Term: ${String(doc.data.term||'')}`,11);line(`Grading scale: ${doc.data.scale==='numeric'?'1-100':'A-F'}`,10);heading('Subjects and grades');for(const subject of doc.data.subjects as Row[]||[]){room(30);line(`${subject.name||''}     ${subject.grade||''}`,11);separator();}if(doc.data.remarks){heading('Teacher remarks');line(String(doc.data.remarks),10);}}
 pageFooter();return new Blob([await pdf.save() as BlobPart],{type:'application/pdf'});
}
export async function exportSchoolPdf(doc:SchoolDocument,studentName='',share=false){const blob=await buildSchoolPdf(doc,studentName);await deliverPdf(blob,`${doc.kind}-${doc.title.replace(/[^a-z0-9]+/gi,'-').replace(/^-|-$/g,'')||'school'}.pdf`,doc.title,share);}
