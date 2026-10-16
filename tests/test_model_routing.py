import sys,json,unittest,io
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'service'))
import server
class RoutingTest(unittest.TestCase):
 def test_generation_and_dialogue_use_separate_models_endpoints_and_keys(self):
  observed=[]
  def fake_open(request,timeout):
   observed.append((request.full_url,json.loads(request.data)['model'],request.get_header('Authorization')))
   return io.BytesIO(json.dumps({'choices':[{'message':{'content':'Сәлеметсіз бе!'}}]}).encode())
  config={'ALEM_API_KEY':'generation-test-only','ALEM_MODEL':'gemma4','ALEM_URL':'https://llm.alem.ai/v1/chat/completions','ALEM_CHAT_API_KEY':'chat-test-only','ALEM_CHAT_MODEL':'gpt-oss','ALEM_CHAT_URL':'https://llm.alem.ai/chat/completions'}
  with patch.dict(server.os.environ,config),patch.object(server.urllib.request,'urlopen',fake_open):
   server.llm([{'role':'user','content':'Generate'}])
   server.llm([{'role':'user','content':'Interview'}],purpose='chat')
  self.assertEqual(observed,[('https://llm.alem.ai/v1/chat/completions','gemma4','Bearer generation-test-only'),('https://llm.alem.ai/chat/completions','gpt-oss','Bearer chat-test-only')])
if __name__=='__main__': unittest.main()
