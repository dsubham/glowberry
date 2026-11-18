import {describe,it,expect,vi} from 'vitest';
import {readFile} from 'node:fs/promises';
import {PDFDocument} from 'pdf-lib';
import {addDays,monthStart,validateFeeMonth,validateReport,validateReportImages,weekStart,type CareStudent,type StudentReport} from '../src/care-data';
import {buildReportPdf} from '../src/report-pdf';

const student:CareStudent={id:'student',name:'Aarav',grade:'Nursery',joined_on:'2026-01-01',active:true,photo_path:null};
const report:StudentReport={id:'report',student_id:'student',cadence:'weekly',period_start:'2026-11-02',period_end:'2026-11-08',title:'A week of discovery',summary:'Aarav enjoyed building with blocks.',learning:'We explored colours and shapes.',wellbeing:'Happy and settled.',next_steps:'More counting games.',status:'published',images:[]};
describe('student care',()=>{
 it('keeps school months and weeks date-only',()=>{expect(monthStart('2026-11-17')).toBe('2026-11-01');expect(weekStart('2026-11-17')).toBe('2026-11-16');expect(addDays('2026-11-30',1)).toBe('2026-12-01');});
 it('rejects a future paid date',()=>expect(()=>validateFeeMonth('2026-11-01','2099-01-01')).toThrow());
 it('requires report text and a valid period',()=>{expect(()=>validateReport(report,student.joined_on)).not.toThrow();expect(()=>validateReport({...report,summary:'',learning:'',wellbeing:'',next_steps:''},student.joined_on)).toThrow();expect(()=>validateReport({...report,period_end:'2026-11-10'},student.joined_on)).toThrow();});
 it('rejects unsupported report photos',()=>expect(()=>validateReportImages([{type:'image/webp',size:100} as File])).toThrow());
 it('generates a readable PDF with a photo',async()=>{
  const font=await readFile(new URL('../public/brand/NotoSans-Regular.ttf',import.meta.url));
  const photo=await readFile(new URL('../public/brand/glowberry-logo.jpg',import.meta.url));
  vi.stubGlobal('fetch',async(url:string)=>new Response(url.includes('NotoSans')?font:photo,{status:200}));
  try{const blob=await buildReportPdf(student,{...report,images:[{id:'image',report_id:'report',path:'',caption:'Building and learning',mime:'image/jpeg',url:'/photo.jpg'}]});const bytes=await blob.arrayBuffer();const document=await PDFDocument.load(bytes);expect(document.getPageCount()).toBeGreaterThanOrEqual(1);expect(bytes.byteLength).toBeGreaterThan(2000);}finally{vi.unstubAllGlobals();}
 });
});
