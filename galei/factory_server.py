from __future__ import annotations
import json, os, time, urllib.parse, urllib.request
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'output'; OUT.mkdir(exist_ok=True)
ACE=os.environ.get('GALEI_ACE_URL','http://127.0.0.1:8001').rstrip('/')
PORT=8765

def req(url,method='GET',payload=None,timeout=30):
    data=None if payload is None else json.dumps(payload,ensure_ascii=False).encode('utf-8')
    r=urllib.request.Request(url,data=data,headers={'Content-Type':'application/json'},method=method)
    with urllib.request.urlopen(r,timeout=timeout) as x:return json.loads(x.read().decode('utf-8'))

def send_audio(remote):
    if remote.startswith('http'): url=remote
    elif remote.startswith('/v1/audio'): url=ACE+remote
    else:url=ACE+'/v1/audio?'+urllib.parse.urlencode({'path':remote})
    with urllib.request.urlopen(url,timeout=180) as r:return r.read(),r.headers.get_content_type()

class H(SimpleHTTPRequestHandler):
    def __init__(self,*a,**k): super().__init__(*a,directory=str(ROOT),**k)
    def j(self,obj,code=200):
        b=json.dumps(obj,ensure_ascii=False).encode(); self.send_response(code); self.send_header('Content-Type','application/json; charset=utf-8'); self.send_header('Content-Length',str(len(b))); self.end_headers(); self.wfile.write(b)
    def body(self): return json.loads(self.rfile.read(int(self.headers.get('Content-Length','0') or 0)).decode() or '{}')
    def do_GET(self):
        p=urllib.parse.urlparse(self.path)
        if p.path=='/api/status':
            try:self.j({'factory':True,'ace':req(ACE+'/health',timeout=3)})
            except Exception as e:self.j({'factory':True,'ace':False,'error':str(e)})
            return
        if p.path=='/api/result':
            q=urllib.parse.parse_qs(p.query); tid=(q.get('task_id')or[''])[0]
            try:self.j(req(ACE+'/query_result','POST',{'task_id_list':[tid]},20))
            except Exception as e:self.j({'error':str(e)},502)
            return
        if p.path=='/api/audio':
            q=urllib.parse.parse_qs(p.query); remote=(q.get('path')or[''])[0]
            try:
                b,ct=send_audio(remote); self.send_response(200); self.send_header('Content-Type',ct or 'audio/mpeg'); self.send_header('Content-Length',str(len(b))); self.end_headers(); self.wfile.write(b)
            except Exception as e:self.j({'error':str(e)},502)
            return
        if p.path=='/': self.path='/index.html'
        super().do_GET()
    def do_POST(self):
        if self.path=='/api/generate':
            d=self.body(); payload={'prompt':d['style'],'lyrics':d['lyrics'],'vocal_language':'he','audio_format':'mp3','model':'acestep-v15-turbo','thinking':bool(d.get('thinking',True)),'use_format':False,'audio_duration':int(d.get('duration',75)),'batch_size':int(d.get('variations',2)),'inference_steps':8}
            try:self.j(req(ACE+'/release_task','POST',payload,30))
            except Exception as e:self.j({'error':str(e)},502)
            return
        if self.path=='/api/export':
            d=self.body(); remote=d['path']; mid=d.get('moduleId','song')
            try:
                b,_=send_audio(remote); fn=OUT/f'{mid}.mp3'; fn.write_bytes(b); meta={'moduleId':mid,'lyrics':d.get('lyrics',''),'style':d.get('style',''),'createdAt':time.strftime('%Y-%m-%dT%H:%M:%S'),'file':fn.name}; (OUT/f'{mid}.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8'); self.j({'ok':True,'file':str(fn)})
            except Exception as e:self.j({'error':str(e)},502)
            return
        self.j({'error':'unknown endpoint'},404)

if __name__=='__main__':
    print('Galei Song Factory http://127.0.0.1:8765')
    ThreadingHTTPServer(('127.0.0.1',PORT),H).serve_forever()
