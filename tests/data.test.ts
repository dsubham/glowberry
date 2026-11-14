import { describe,it,expect } from 'vitest';
import { usernameEmail,validateFiles } from '../src/data';
describe('school usernames',()=>{
 it('normalises school-issued usernames',()=>expect(usernameEmail(' Parent.Ananya ')).toBe('parent.ananya@accounts.glowberryutopia.in'));
 it.each(['a','someone@example.com','hello world','../admin','<script>'])('rejects invalid username %s',name=>expect(()=>usernameEmail(name)).toThrow());
});
describe('file boundaries',()=>{
 const file=(type:string,size=100)=>({name:'test',type,size} as File);
 it('rejects oversized images',()=>expect(()=>validateFiles([file('image/jpeg',10485761)],'activity')).toThrow('10 MB'));
 it('rejects executable and SVG content',()=>{for(const type of ['text/html','image/svg+xml','application/javascript'])expect(()=>validateFiles([file(type)],'attachment')).toThrow();});
 it('keeps activity attachments image-only',()=>expect(()=>validateFiles([file('application/pdf')],'activity')).toThrow('photos only'));
 it('allows PDFs for school documents',()=>expect(()=>validateFiles([file('application/pdf')],'attachment')).not.toThrow());
 it('limits one update to eight files',()=>expect(()=>validateFiles(Array.from({length:9},()=>file('image/png')),'activity')).toThrow('8 files'));
});
