import { PDFDocument, rgb } from 'pdf-lib';
import fontkit from '@pdf-lib/fontkit';
import { Capacitor } from '@capacitor/core';
import { Filesystem, Directory } from '@capacitor/filesystem';
import { Share } from '@capacitor/share';
import type { CareStudent, StudentReport } from './care-data';

const paper={width:595.28,height:841.89};
const ink=rgb(0.22,0.18,0.2),muted=rgb(0.43,0.43,0.43),berry=rgb(0.43,0.10,0.22),leaf=rgb(0.42,0.52,0.35);
function niceDate(day:string){return new Intl.DateTimeFormat('en-IN',{day:'numeric',month:'long',year:'numeric',timeZone:'UTC'}).format(new Date(`${day}T12:00:00Z`));}
function fileName(student:CareStudent,report:StudentReport){return `${student.name.replace(/[^a-z0-9]+/gi,'-').replace(/^-|-$/g,'')||'student'}-${report.cadence}-${report.period_start}.pdf`;}
export async function buildReportPdf(student:CareStudent,report:StudentReport):Promise<Blob>{
 const pdf=await PDFDocument.create();pdf.registerFontkit(fontkit);
 const fontResponse=await fetch('/brand/NotoSans-Regular.ttf');if(!fontResponse.ok)throw new Error('Unable to load the report font.');
 const font=await pdf.embedFont(await fontResponse.arrayBuffer(),{subset:true});
 let page=pdf.addPage([paper.width,paper.height]),y=paper.height-50,pageNumber=1;
 function header(){page.drawText('GLOWBERRY UTOPIA',{x:44,y:paper.height-42,size:10,font,color:berry});page.drawText('Nurturing curious minds',{x:paper.width-185,y:paper.height-42,size:8,font,color:muted});page.drawLine({start:{x:44,y:paper.height-52},end:{x:paper.width-44,y:paper.height-52},thickness:1,color:leaf});}
 function footer(){page.drawLine({start:{x:44,y:44},end:{x:paper.width-44,y:44},thickness:.6,color:leaf});page.drawText('A little care. A lot of possibility.',{x:44,y:29,size:8,font,color:muted});page.drawText(String(pageNumber),{x:paper.width-52,y:29,size:8,font,color:muted});}
 function nextPage(){footer();page=pdf.addPage([paper.width,paper.height]);pageNumber++;header();y=paper.height-75;}
 function room(height:number){if(y-height<63)nextPage();}
 function lines(text:string,size:number,maxWidth:number){const result:string[]=[];for(const paragraph of text.split(/\n/)){if(!paragraph.trim()){result.push('');continue;}let line='';for(const word of paragraph.trim().split(/\s+/)){const trial=line?`${line} ${word}`:word;if(font.widthOfTextAtSize(trial,size)>maxWidth&&line){result.push(line);line=word;}else line=trial;}result.push(line);}return result;}
 function paragraph(text:string,size=10,color=ink){for(const line of lines(text,size,paper.width-88)){room(size+6);if(line)page.drawText(line,{x:44,y,size,font,color});y-=size+6;}}
 function section(title:string,body:string){if(!body.trim())return;room(52);y-=10;page.drawText(title.toUpperCase(),{x:44,y,size:9,font,color:berry});y-=20;paragraph(body.trim());}
 header();y-=30;
 paragraph(report.title,20,berry);y-=5;
 paragraph(`${student.name}  |  ${student.grade}`,11,ink);
 paragraph(report.cadence==='daily'?`Daily report  |  ${niceDate(report.period_start)}`:`Weekly report  |  ${niceDate(report.period_start)} - ${niceDate(report.period_end)}`,9,muted);
 page.drawLine({start:{x:44,y:y-4},end:{x:paper.width-44,y:y-4},thickness:1,color:leaf});y-=22;
 section('Overview',report.summary);section('Learning and activities',report.learning);section('Wellbeing',report.wellbeing);section('Looking ahead',report.next_steps);
 if(report.images.length){room(54);y-=12;page.drawText('ACTIVITY PHOTOS',{x:44,y,size:9,font,color:berry});y-=20;
  for(const image of report.images){if(!image.url)continue;const response=await fetch(image.url);if(!response.ok)throw new Error('Unable to load a report photo.');const bytes=await response.arrayBuffer();const embedded=image.mime==='image/png'?await pdf.embedPng(bytes):await pdf.embedJpg(bytes);const scale=Math.min((paper.width-88)/embedded.width,250/embedded.height,1);const w=embedded.width*scale,h=embedded.height*scale;room(h+42);page.drawImage(embedded,{x:44,y:y-h,width:w,height:h});y-=h+12;if(image.caption.trim())paragraph(image.caption.trim(),9,muted);y-=14;}
 }
 footer();return new Blob([await pdf.save() as BlobPart],{type:'application/pdf'});
}
function download(blob:Blob,name:string){const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download=name;document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),60000);}
export async function deliverPdf(blob:Blob,name:string,title:string,share:boolean){
 if(Capacitor.isNativePlatform()){const bytes=new Uint8Array(await blob.arrayBuffer());let binary='';for(let i=0;i<bytes.length;i+=8192)binary+=String.fromCharCode(...bytes.subarray(i,i+8192));const saved=await Filesystem.writeFile({path:name,data:btoa(binary),directory:Directory.Cache});await Share.share({title,url:saved.uri,dialogTitle:'Share PDF'});return;}
 if(share&&navigator.canShare){const file=new File([blob],name,{type:'application/pdf'});if(navigator.canShare({files:[file]})){await navigator.share({title,files:[file]});return;}}
 download(blob,name);
}
export async function exportReport(student:CareStudent,report:StudentReport,share:boolean){const blob=await buildReportPdf(student,report);await deliverPdf(blob,fileName(student,report),report.title,share);}
