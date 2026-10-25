import sys, json
sys.path.insert(0,'/workspace')
from asc import req
apps=req('GET','/v1/apps?filter[bundleId]=com.moha700m.shakhsaha')
if not apps.get('data'):
    print('NO_APP_RECORD'); sys.exit(2)
app=apps['data'][0]['id']; print('app',app)
g=req('GET',f'/v1/apps/{app}/betaGroups')
grp=[x for x in g.get('data',[]) if x['attributes']['name']=='Internal']
if grp: gid=grp[0]['id']
else:
    r=req('POST','/v1/betaGroups',{"data":{"type":"betaGroups","attributes":{"name":"Internal","isInternalGroup":True,"hasAccessToAllBuilds":True},"relationships":{"app":{"data":{"type":"apps","id":app}}}}})
    print(json.dumps(r)[:600]); gid=r['data']['id']
print('group',gid)
r=req('POST','/v1/betaTesters',{"data":{"type":"betaTesters","attributes":{"email":"m.alzhrani977@gmail.com"},"relationships":{"betaGroups":{"data":[{"type":"betaGroups","id":gid}]}}}})
print('tester',json.dumps(r)[:400])
b=req('GET',f'/v1/builds?filter[app]={app}&sort=-uploadedDate&limit=3')
for x in b.get('data',[]): print('build',x['attributes'].get('version'),x['attributes'].get('processingState'),x['id'])
