import {describe,it,expect,vi} from 'vitest';
import {readFile} from 'node:fs/promises';
import {PDFDict,PDFDocument,PDFName} from 'pdf-lib';
import {newDocument,validateDocument,type SchoolDocument} from '../src/workflows-data';
import {buildSchoolPdf} from '../src/school-pdf';
describe('school documents',()=>{
 it('requires a student for marksheets',()=>expect(()=>validateDocument({...newDocument('marksheet'),data:{scale:'letter',subjects:[{name:'English',grade:'A'}]}})).toThrow());
 it('requires calendar events',()=>expect(()=>validateDocument(newDocument('calendar'))).toThrow());
 it('makes printable PDFs with the Glowberry logo for every document type',async()=>{const font=await readFile(new URL('../public/brand/NotoSans-Regular.ttf',import.meta.url));const logo=await readFile(new URL('../public/brand/glowberry-logo.jpg',import.meta.url));vi.stubGlobal('fetch',async(url:string)=>new Response(url.includes('NotoSans')?font:logo,{status:200}));try{const samples:SchoolDocument[]=[{...newDocument('calendar'),data:{events:[{date:'2026-11-18',title:'School celebration',details:'Families welcome'}]}},{...newDocument('timetable'),data:{class_name:'Nursery',rows:[{day:'Monday',time:'9:00',activity:'Circle time'}]}},newDocument('admission'),{...newDocument('marksheet'),student_id:'child',data:{term:'Term 1',scale:'numeric',subjects:[{name:'English',grade:90}],remarks:'Good progress'}}];for(const doc of samples){const blob=await buildSchoolPdf(doc,'Aarav');const bytes=await blob.arrayBuffer();const loaded=await PDFDocument.load(bytes);const xObjects=loaded.getPage(0).node.Resources()?.lookup(PDFName.of('XObject'),PDFDict);expect(xObjects?.keys().length).toBeGreaterThan(0);expect(bytes.byteLength).toBeGreaterThan(1000);}}finally{vi.unstubAllGlobals();}});
});
