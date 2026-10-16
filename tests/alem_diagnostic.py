import sys,time,json,urllib.request,socket,ssl
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'service'))
import server
host='llm.alem.ai'
t=time.monotonic()
with socket.create_connection((host,443),timeout=15) as sock:
 print('TCP seconds:',round(time.monotonic()-t,2),flush=True)
 with ssl.create_default_context().wrap_socket(sock,server_hostname=host) as tls:
  print('TLS seconds:',round(time.monotonic()-t,2),flush=True)
payload={'model':'gemma4','messages':[{'role':'user','content':'Сәлем! Қазақша бір сөйлеммен жауап бер.'}],'max_tokens':128}
req=urllib.request.Request(server.os.environ['ALEM_URL'],data=json.dumps(payload).encode(),headers={'Authorization':'Bearer '+server.os.environ['ALEM_API_KEY'],'Content-Type':'application/json'})
t=time.monotonic()
try:
 with urllib.request.urlopen(req,timeout=90) as r:
  print('HTTP headers after:',round(time.monotonic()-t,2),r.status,flush=True)
  d=json.load(r)
 print('Finish:',d['choices'][0].get('finish_reason'),'usage:',d.get('usage'),flush=True)
 print('Answer:',d['choices'][0]['message'].get('content'),flush=True)
except Exception as e: print('FAILED:',type(e).__name__,str(e),'after',round(time.monotonic()-t,2),flush=True)
