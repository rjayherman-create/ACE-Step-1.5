from __future__ import annotations
import json, os, time, urllib.parse, urllib.request
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'output'; OUT.mkdir(exist_ok=True)
PROFILE_PATH=ROOT/'computer-profile.json'
ACE=os.environ.get('GALEI_ACE_URL','http://127.0.0.1:8001').rstrip('/')
PORT=8765

def req(url,method='GET',payload=None,timeout=30):
    data=None if payload is None else json.dumps(payload,ensure_ascii=False).encode('utf-8')
    r=urllib.request.Request(url,data=data,headers={'Content-Type':'application/json'},method=method)
    with urllib.request.urlopen(r,timeout=timeout) as x:return json.loads(x.read().decode('utf-8'))

def load_profile():
    try:return json.loads(PROFILE_PATH.read_text(encoding='utf-8-sig'))
    except Exception:return {'profile':'safe-default','vramGB':0,'gpu':'unknown'}

def safe_generation_settings(requested_variations:int):
    p=load_profile(); vram=float(p.get('vramGB') or 0); gpu=str(p.get('gpu') or '')
    legacy=any(x in gpu.lower() for x in ['quadro','gtx 10','p1000','p2000','p3000','p4000','p5000','p6000'])
    # First priority is a successful full-audio render on older hardware.
    # DiT-only still generates complete mixed music with vocals; it simply avoids the extra LM planner.
    if vram <= 8 or legacy or not vram:
        return p, {'thinking':False,'batch_size':1,'use_cot_caption':False,'use_cot_language':False,'bpm':112,'key_scale':'C Major','time_signature':'4','inference_steps':8}, 'SAFE LOCAL'
    return p, {'thinking':True,'batch_size':min(max(1,requested_variations),2),'use_cot_caption':True,'use_cot_language':True,'inference_steps':8}, 'QUALITY LOCAL'

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
            profile=load_profile()
            try:self.j({'factory':True,'ace':req(ACE+'/health',timeout=3),'profile':profile})
            except Exception as e:self.j({'factory':True,'ace':False,'profile':profile,'error':str(e)})
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
            d=self.body(); profile,extra,mode=safe_generation_settings(int(d.get('variations',1)))
            payload={'prompt':d['style'],'lyrics':d['lyrics'],'vocal_language':'he','audio_format':'mp3','model':'acestep-v15-turbo','use_format':False,'audio_duration':int(d.get('duration',75)),**extra}
            try:
                result=req(ACE+'/release_task','POST',payload,30)
                if isinstance(result,dict):result['galei_mode']=mode;result['galei_profile']=profile;result['galei_settings']={'thinking':payload['thinking'],'batch_size':payload['batch_size'],'model':payload['model']}
                self.j(result)
            except Exception as e:self.j({'error':str(e),'galei_mode':mode,'galei_profile':profile},502)
            return
        if self.path=='/api/export':
            d=self.body(); remote=d['path']; mid=d.get('moduleId','song')
            try:
                b,_=send_audio(remote); fn=OUT/f'{mid}.mp3'; fn.write_bytes(b); meta={'moduleId':mid,'lyrics':d.get('lyrics',''),'style':d.get('style',''),'createdAt':time.strftime('%Y-%m-%dT%H:%M:%S'),'file':fn.name}; (OUT/f'{mid}.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8'); self.j({'ok':True,'file':str(fn)})
            except Exception as e:self.j({'error':str(e)},502)
            return
        self.j({'error':'unknown endpoint'},404)

if __name__=='__main__':
    p=load_profile(); print('Galei Song Factory http://127.0.0.1:8765'); print('Hardware profile:',json.dumps(p,ensure_ascii=False))
    ThreadingHTTPServer(('127.0.0.1',PORT),H).serve_forever()
