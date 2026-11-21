# -*- coding: utf-8 -*-
# 批量生成 38 台装机 kit：从 git 历史找回原件，生成 install-coreN + goN（hostname=ctyun-<手机号>）
import os, subprocess

KIT = r'F:/天翼云电脑/kit-github'
phones = ["13135730983","13135732872","13135739703","13135739862","13136378261","13206596221","13216695093","15558250697","15558363559","16645947040","16657172065","17332308850","17370252947","17395213370","17731464867","19131446974","19906705515","19912324051","19930343733","19931440614","19931442495","19931581429","19957025579","19957027856","19957860261","19957860506","19957881279","19975225920","19975226972","19975246163","13135730911","13135731150","13224179778","13250968763","19906547867","19957032757","19957448031","17367564148"]

def git(*args):
    return subprocess.run(['git', '-C', KIT] + list(args), capture_output=True, text=True, encoding='utf-8', errors='replace').stdout

log = git('log', '--oneline', '-10').strip().splitlines()
print('\n'.join(log))
core = None
go = None
for line in log:
    sha = line.split()[0]
    c = git('show', sha + ':install-core7.ps1')
    g = git('show', sha + ':go11.ps1')
    if c and 'tskey-auth' in c and g and 'fastly' in g and 'install-core7' in g:
        core, go = c, g
        print('recovered from', sha)
        break
assert core and 'tskey-auth' in core, 'recovery failed'
assert 'ctyun-15582' in core, 'core hostname base wrong'

manifest = []
goN = 12
coreN = 8
for p in phones:
    host = 'ctyun-' + p
    coref = 'install-core%d.ps1' % coreN
    gof = 'go%d.ps1' % goN
    c = core.replace('ctyun-15582', host)
    g = go.replace('install-core7.ps1', coref).replace('ctyun-15582', host)
    open(os.path.join(KIT, coref), 'w', encoding='utf-8').write(c)
    open(os.path.join(KIT, gof), 'w', encoding='utf-8').write(g)
    manifest.append('%s %s %s %s' % (p, host, gof, coref))
    coreN += 1
    goN += 1

open(os.path.join(KIT, 'batch-manifest.txt'), 'w', encoding='utf-8').write('\n'.join(manifest))
print('generated', len(manifest), 'kits (go12..go%d)' % (goN - 1))
