import io, urllib.request, zipfile, time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
URL='https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_export_templates.tpz'
class RemoteZip(io.RawIOBase):
    def __init__(self):
        r=urllib.request.urlopen(urllib.request.Request(URL+'?basqaru='+str(int(time.time())),method='HEAD'),timeout=30)
        self.url=r.url; self.length=int(r.headers['Content-Length']); self.position=0
    def seekable(self): return True
    def seek(self,offset,whence=0):
        self.position=offset if whence==0 else (self.position+offset if whence==1 else self.length+offset)
        return self.position
    def tell(self): return self.position
    def read(self,size=-1):
        if size<0: size=self.length-self.position
        if size==0:return b''
        end=min(self.length,self.position+size)-1
        def part(bounds):
            a,b=bounds
            req=urllib.request.Request(self.url,headers={'Range':f'bytes={a}-{b}'})
            with urllib.request.urlopen(req,timeout=30) as r:
                if r.status!=206: raise RuntimeError('Server does not support ranges')
                data=r.read(b-a+1)
                if len(data)!=b-a+1: raise RuntimeError('Incomplete download')
                return data
        ranges=[(a,min(a+1048575,end)) for a in range(self.position,end+1,1048576)]
        with ThreadPoolExecutor(max_workers=6) as pool: data=b''.join(pool.map(part,ranges))
        self.position+=len(data);return data
out=Path.home()/'.local/share/godot/export_templates/4.4.1.stable'
out.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(RemoteZip()) as archive:
    for name in ['linux_release.x86_64','windows_release_x86_64.exe','version.txt']:
        info=archive.getinfo('templates/'+name)
        print('Downloading',name,info.compress_size,'bytes',flush=True)
        data=archive.read(info)
        (out/name).write_bytes(data)
        (out/name).chmod(0o755)
        print('Verified ZIP CRC:',name,len(data),flush=True)
