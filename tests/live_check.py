import sys, threading, json, urllib.request, urllib.error, time, itertools, copy
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'service'))
import server as s
http=s.ThreadingHTTPServer(('127.0.0.1',0),s.Handler)
threading.Thread(target=http.serve_forever,daemon=True).start()
base='http://127.0.0.1:'+str(http.server_port)
def post(path,data,expected=200):
    req=urllib.request.Request(base+path,data=json.dumps(data).encode(),headers={'Content-Type':'application/json'})
    try:
        with urllib.request.urlopen(req,timeout=180) as r:
            assert r.status==expected; return json.load(r)
    except urllib.error.HTTPError as e:
        assert e.code==expected,(e.code,e.read().decode());return json.load(e)
print('Generating real company-specific profiles with Alem AI...',flush=True)
job=post('/new',{'company':'Qadam Studio','description':'Қазақстандағы шағын кәсіпкерлерге сайт пен мобильді қосымша жасаймыз. Клиенттерімізге адал, сапалы және уақытында қызмет көрсету үшін команда жинаймыз.'})['job']
end=time.time()+500
while time.time()<end:
    status=post('/job',{'job':job})
    print(status,flush=True)
    if status['status']!='loading': break
    time.sleep(8)
assert status['status']=='ready',status
sid=status['session']; state=post('/load',{'session':sid})
assert len(state['candidates'])==15
assert len({c['name'] for c in state['candidates']})==15
assert all('stats' not in c and 'weakness' not in c for c in state['candidates'])
assert len({c['group'] for c in state['candidates']})==5
print('15 profiles valid; hidden ratings are not exposed.',flush=True)
reply=post('/chat',{'session':sid,'candidate':0,'message':'Жұмыста жіберген бір қатеңізді айтып беріңіз. Оны қалай түзеттіңіз?'})
assert len(reply['answer'])>30
print('REAL CANDIDATE REPLY:',reply['answer'],flush=True)
reply2=post('/chat',{'session':sid,'candidate':0,'message':'Алдыңғы айтқан қатеңізді болашақта қайталамау үшін не істейсіз?'})
assert len(reply2['answer'])>30
print('FOLLOW-UP:',reply2['answer'],flush=True)
post('/team',{'session':sid,'selected':[0,0]},400)
post('/team',{'session':sid,'selected':[0,1,2,3,4,5]},400)
post('/finish',{'session':sid},400)
post('/note',{'session':sid,'candidate':0,'note':'Нақты мысал келтірді. Тәжірибесін салыстыру керек.'})
state=post('/load',{'session':sid});assert len(state['histories']['0'])==4 and state['notes']['0']
# Preserve unfinished real session for in-engine UI QA.
(s.DATA/'qa-session.txt').write_text(sid)
original=s.get_session(sid)
combos=list(itertools.combinations(range(15),5))
scores=[(s.score({**original,'selected':list(team)})['score'],team) for team in combos]
low=min(scores); high=max(scores)
assert high[0]>=80 and low[0]<60,(low,high)
print('All 3003 possible teams scored. Range:',low[0],high[0],flush=True)
clone=copy.deepcopy(original);clone['id']='f'*32;s.SESSIONS[clone['id']]=clone;s.save(clone)
post('/team',{'session':clone['id'],'selected':list(high[1])})
finished=post('/finish',{'session':clone['id']})
assert finished['finished'] and finished['report']['score']==high[0]
post('/team',{'session':clone['id'],'selected':[]},400)
print('PASS: live LLM, conversation memory, notes, selection limits, score bounds, finalization.',flush=True)
http.shutdown()
