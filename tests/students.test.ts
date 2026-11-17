import {describe,it,expect} from 'vitest';
import {validateStudent,validatePhoto,schoolToday,type Student} from '../src/students-data';
const student:Student={id:'test',name:'Child',parent_name:'Parent',parent_phone:'',grade:'Nursery',admission_number:null,date_of_birth:'2022-01-01',joined_on:'2025-01-01',active:true,photo_path:null,notes:''};
describe('student records',()=>{
 it('accepts a valid record',()=>expect(()=>validateStudent(student)).not.toThrow());
 it('requires names',()=>expect(()=>validateStudent({...student,name:' '})).toThrow());
 it('rejects a birth date after admission',()=>expect(()=>validateStudent({...student,date_of_birth:'2025-01-02'})).toThrow());
 it('rejects future admissions',()=>expect(()=>validateStudent({...student,joined_on:'2099-01-01'})).toThrow());
 it('uses a date-only school day',()=>expect(schoolToday()).toMatch(/^\d{4}-\d{2}-\d{2}$/));
 it('rejects unsafe or oversized photos',()=>{for(const f of [{type:'image/svg+xml',size:100},{type:'image/jpeg',size:5242881}])expect(()=>validatePhoto(f as File)).toThrow();});
});
