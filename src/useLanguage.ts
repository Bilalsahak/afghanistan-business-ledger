import{useEffect,useState}from'react';

export type AppLanguage='en'|'fa'|'ps';

export function useLanguage(){
  const read=():AppLanguage=>{const value=document.documentElement.lang;return value==='fa'||value==='ps'?value:'en'};
  const[language,setLanguage]=useState<AppLanguage>(read);
  useEffect(()=>{const update=()=>setLanguage(read());window.addEventListener('business-language-change',update);return()=>window.removeEventListener('business-language-change',update)},[]);
  return language;
}
