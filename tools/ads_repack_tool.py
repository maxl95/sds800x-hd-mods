#!/usr/bin/env python3
# Self-contained Siglent .ADS repack tool + round-trip verifier.
# - decode/confuse (obfuscation inverse), non-standard LSB-first 2-key 3DES
# - surgical replacement of the update.sh member (leaves siglent.ext4 untouched)
# - round-trip test: re-encode original unchanged -> must be byte-identical
# - repack verify: decode the repack, walk members, check CRCs vs originals
import sys, struct, zlib, io

# ---------- DES core (standard tables; Siglent LSB-first deviation) ----------
_IP=[58,50,42,34,26,18,10,2,60,52,44,36,28,20,12,4,62,54,46,38,30,22,14,6,64,56,48,40,32,24,16,8,57,49,41,33,25,17,9,1,59,51,43,35,27,19,11,3,61,53,45,37,29,21,13,5,63,55,47,39,31,23,15,7]
_FP=[40,8,48,16,56,24,64,32,39,7,47,15,55,23,63,31,38,6,46,14,54,22,62,30,37,5,45,13,53,21,61,29,36,4,44,12,52,20,60,28,35,3,43,11,51,19,59,27,34,2,42,10,50,18,58,26,33,1,41,9,49,17,57,25]
_E=[32,1,2,3,4,5,4,5,6,7,8,9,8,9,10,11,12,13,12,13,14,15,16,17,16,17,18,19,20,21,20,21,22,23,24,25,24,25,26,27,28,29,28,29,30,31,32,1]
_P=[16,7,20,21,29,12,28,17,1,15,23,26,5,18,31,10,2,8,24,14,32,27,3,9,19,13,30,6,22,11,4,25]
_PC1=[57,49,41,33,25,17,9,1,58,50,42,34,26,18,10,2,59,51,43,35,27,19,11,3,60,52,44,36,63,55,47,39,31,23,15,7,62,54,46,38,30,22,14,6,61,53,45,37,29,21,13,5,28,20,12,4]
_PC2=[14,17,11,24,1,5,3,28,15,6,21,10,23,19,12,4,26,8,16,7,27,20,13,2,41,52,31,37,47,55,30,40,51,45,33,48,44,49,39,56,34,53,46,42,50,36,29,32]
_SHIFT=[1,1,2,2,2,2,2,2,1,2,2,2,2,2,2,1]
_SBOX=[
[14,4,13,1,2,15,11,8,3,10,6,12,5,9,0,7,0,15,7,4,14,2,13,1,10,6,12,11,9,5,3,8,4,1,14,8,13,6,2,11,15,12,9,7,3,10,5,0,15,12,8,2,4,9,1,7,5,11,3,14,10,0,6,13],
[15,1,8,14,6,11,3,4,9,7,2,13,12,0,5,10,3,13,4,7,15,2,8,14,12,0,1,10,6,9,11,5,0,14,7,11,10,4,13,1,5,8,12,6,9,3,2,15,13,8,10,1,3,15,4,2,11,6,7,12,0,5,14,9],
[10,0,9,14,6,3,15,5,1,13,12,7,11,4,2,8,13,7,0,9,3,4,6,10,2,8,5,14,12,11,15,1,13,6,4,9,8,15,3,0,11,1,2,12,5,10,14,7,1,10,13,0,6,9,8,7,4,15,14,3,11,5,2,12],
[7,13,14,3,0,6,9,10,1,2,8,5,11,12,4,15,13,8,11,5,6,15,0,3,4,7,2,12,1,10,14,9,10,6,9,0,12,11,7,13,15,1,3,14,5,2,8,4,3,15,0,6,10,1,13,8,9,4,5,11,12,7,2,14],
[2,12,4,1,7,10,11,6,8,5,3,15,13,0,14,9,14,11,2,12,4,7,13,1,5,0,15,10,3,9,8,6,4,2,1,11,10,13,7,8,15,9,12,5,6,3,0,14,11,8,12,7,1,14,2,13,6,15,0,9,10,4,5,3],
[12,1,10,15,9,2,6,8,0,13,3,4,14,7,5,11,10,15,4,2,7,12,9,5,6,1,13,14,0,11,3,8,9,14,15,5,2,8,12,3,7,0,4,10,1,13,11,6,4,3,2,12,9,5,15,10,11,14,1,7,6,0,8,13],
[4,11,2,14,15,0,8,13,3,12,9,7,5,10,6,1,13,0,11,7,4,9,1,10,14,3,5,12,2,15,8,6,1,4,11,13,12,3,7,14,10,15,6,8,0,5,9,2,6,11,13,8,1,4,10,7,9,5,0,15,14,2,3,12],
[13,2,8,4,6,15,11,1,10,9,3,14,5,0,12,7,1,15,13,8,10,3,7,4,12,5,6,11,0,14,9,2,7,11,4,1,9,12,14,2,0,6,10,13,15,3,5,8,2,1,14,7,4,10,8,13,15,12,9,0,3,5,6,11]]
def _perm(b,t): return [b[i-1] for i in t]
def _b2b(b):
    o=[]
    for by in b:
        for i in range(8): o.append((by>>i)&1)
    return o
def _bits2b(bits):
    o=bytearray()
    for i in range(0,len(bits),8):
        v=0
        for j,bit in enumerate(bits[i:i+8]): v|=bit<<j
        o.append(v)
    return bytes(o)
def _subkeys(k8):
    k=_perm(_b2b(k8),_PC1); C,D=k[:28],k[28:]; ks=[]
    for s in _SHIFT:
        C=C[s:]+C[:s]; D=D[s:]+D[:s]; ks.append(_perm(C+D,_PC2))
    return ks
def _feistel(R,k):
    x=[a^b for a,b in zip(_perm(R,_E),k)]; out=[]
    for i in range(8):
        blk=x[i*6:i*6+6]
        row=(blk[0]<<1)|blk[5]; col=(blk[1]<<3)|(blk[2]<<2)|(blk[3]<<1)|blk[4]
        v=_SBOX[i][row*16+col]
        out+=[v&1,(v>>1)&1,(v>>2)&1,(v>>3)&1]
    return _perm(out,_P)
def _enc(b8,k8):
    ks=_subkeys(k8); bits=_perm(_b2b(b8),_IP); L,R=bits[:32],bits[32:]
    for k in ks: L,R=R,[a^b for a,b in zip(L,_feistel(R,k))]
    return _bits2b(_perm(L+R,_FP))
def _dec(b8,k8):
    ks=list(reversed(_subkeys(k8))); bits=_perm(_b2b(b8),_IP); L,R=bits[:32],bits[32:]
    for k in ks: L,R=[a^b for a,b in zip(_feistel(L,k),R)],L
    return _bits2b(_perm(L+R,_FP))
def d3dec(data,k1,k2):
    out=bytearray()
    for i in range(0,len(data)//8*8,8):
        b=data[i:i+8]; out+=_dec(_enc(_dec(b,k1),k2),k1)
    return bytes(out)
def d3enc(data,k1,k2):
    out=bytearray()
    for i in range(0,len(data)//8*8,8):
        b=data[i:i+8]; out+=_enc(_dec(_enc(b,k1),k2),k1)
    return bytes(out)

DESKEY=bytes.fromhex("630321010f0100071710184e5b693706"); K1,K2=DESKEY[:8],DESKEY[8:16]
REGIONS=[(0x0,0x2800),(0x2e777,0x1400)]; HDR=112

def decode(ads):
    p=bytearray(ads[HDR:])
    for off,ln in REGIONS:
        n=ln//8*8; p[off:off+n]=d3dec(bytes(p[off:off+n]),K1,K2)
    b=bytearray(p)[::-1]; L=len(b); H=L//2
    for i in range(L-H,L): b[i]^=0xFF
    n=1
    while True:
        t=n*(n+1)//2
        if t>=L: break
        b[t]^=0xFF; n+=1
    return bytes(b)

def confuse(stream):
    b=bytearray(stream); L=len(b); H=L//2
    n=1
    while True:
        t=n*(n+1)//2
        if t>=L: break
        b[t]^=0xFF; n+=1
    for i in range(L-H,L): b[i]^=0xFF
    b=b[::-1]
    for off,ln in REGIONS:
        n=ln//8*8; b[off:off+n]=d3enc(bytes(b[off:off+n]),K1,K2)
    return bytes(b)

def check_word(data, extra=0): return (-(sum(data)+extra)) & 0xffffffff
def rebuild_header(ref112, stream, payload):
    h=bytearray(d3dec(ref112,K1,K2))
    struct.pack_into("<I",h,0x04,len(stream))
    struct.pack_into("<I",h,0x00,0)
    struct.pack_into("<I",h,0x00,check_word(payload,sum(h[4:])))
    return d3enc(bytes(h),K1,K2)

def build_member(name, data):
    comp=zlib.compressobj(6,zlib.DEFLATED,-15); defl=comp.compress(data)+comp.flush()
    nb=name.encode()
    hdr=struct.pack("<IHHHHHIIIHH",0x04034B50,20,0,8,0,0,zlib.crc32(data)&0xffffffff,len(defl),len(data),len(nb),0)
    return hdr+nb+defl

# ---------- ZIP (central-directory based) ----------
ZIP_BASE=0x34
def parse_zip(dec):
    e=dec.rfind(b"PK\x05\x06"); assert e>=0,"no EOCD"
    _,_,_,_,ntot,cdsize,cdoff,clen=struct.unpack_from("<IHHHHIIH",dec,e)
    cd_abs=ZIP_BASE+cdoff
    entries=[]; p=cd_abs
    for _ in range(ntot):
        assert dec[p:p+4]==b"PK\x01\x02"
        (sig,vm,vn,fl,meth,mt,md,crc,csz,usz,nl,el,cl,dsk,ia,ea,lho)=struct.unpack_from("<IHHHHHHIIIHHHHHII",dec,p)
        name=dec[p+46:p+46+nl].decode("utf-8","replace")
        entries.append(dict(name=name,crc=crc,csize=csz,usize=usz,lho=lho,lho_abs=ZIP_BASE+lho,
                            method=meth,flags=fl,nl=nl,el=el,cl=cl,cdpos=p,cdlen=46+nl+el+cl))
        p+=46+nl+el+cl
    return dict(eocd=e,cd_abs=cd_abs,cdsize=cdsize,cdoff=cdoff,ntot=ntot,entries=entries)

def local_record_len(dec, lho_abs, csize):
    sig,ver,fl,meth,mt,md,crc,csz,usz,nl,el=struct.unpack_from("<IHHHHHIIIHH",dec,lho_abs)
    assert sig==0x04034B50,"bad local sig @%#x"%lho_abs
    body=30+nl+el+csize
    if fl & 0x08:  # data descriptor present
        pos=lho_abs+body
        dd=dec[pos:pos+4]
        body += 16 if dd==b"PK\x07\x08" else 12
    return body, fl

def replace_update_sh(dec, new_data):
    z=parse_zip(dec)
    tgt=[e for e in z["entries"] if e["name"].rstrip("/")=="update.sh"]
    assert len(tgt)==1,"update.sh not found/unique"
    u=tgt[0]
    rec_len,fl=local_record_len(dec,u["lho_abs"],u["csize"])
    old_end=u["lho_abs"]+rec_len
    newrec=build_member("update.sh",new_data)
    delta=len(newrec)-rec_len
    # new central directory
    new_cd=bytearray()
    for e in z["entries"]:
        raw=bytearray(dec[e["cdpos"]:e["cdpos"]+e["cdlen"]])
        if e is u:
            struct.pack_into("<I",raw,16,zlib.crc32(new_data)&0xffffffff)
            struct.pack_into("<I",raw,20,len(newrec)-30-len(b"update.sh"))  # csize
            struct.pack_into("<I",raw,24,len(new_data))                     # usize
            struct.pack_into("<H",raw,10,0)  # method deflate(8)? set below
            struct.pack_into("<H",raw,10,8)  # flags field is at off10? -> fix: set method
        if e["lho_abs"]>u["lho_abs"]:
            struct.pack_into("<I",raw,42,e["lho"]+delta)  # local header offset
        new_cd+=raw
    # reassemble body (everything after 0x34)
    pre=dec[ZIP_BASE:u["lho_abs"]]
    mid=dec[old_end:z["cd_abs"]]            # members after update.sh (raw, unchanged bytes)
    # new eocd
    eocd=bytearray(dec[z["eocd"]:])
    struct.pack_into("<I",eocd,16, z["cdoff"]+delta)   # cd offset shifts by delta
    struct.pack_into("<I",eocd,12, len(new_cd))        # cd size (same unless name len changed)
    body=bytes(pre)+newrec+bytes(mid)+bytes(new_cd)+bytes(eocd)
    container=struct.pack("<III",check_word(body),len(body),7)+b"\x00"*(0x34-12)
    return container+body

def make_ads(orig_ads, new_decoded):
    payload=confuse(new_decoded)
    header=rebuild_header(orig_ads[:HDR], new_decoded, payload)
    return header+payload

# ---------------------------- CLI ----------------------------
import os
# Ortsunabhaengig: Tool liegt in <Projekt>/tools/, die Original-.ADS eine Ebene darueber.
# Ueberschreibbar per Umgebungsvariablen SDS_ADS / SDS_DEC.
_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)
ADS = os.environ.get("SDS_ADS") or os.path.join(_ROOT, "SDS800X-HD_1.1.6.5.ADS")
DEC = os.environ.get("SDS_DEC") or os.path.join(_HERE, "decoded.bin")  # optionaler Cache
MEMBERS=["bsp/Image","bsp/system.dtb","firmdata0/factory_setting.xml","siglent.ext4","update_config"]

def _load_dec():
    # Nutzt decoded.bin falls vorhanden, sonst wird die Original-.ADS on-the-fly dekodiert.
    if os.path.exists(DEC):
        return open(DEC,"rb").read()
    return decode(open(ADS,"rb").read())

def selftest():
    import zipfile
    orig=open(ADS,"rb").read(); dec=_load_dec()
    print("=== ZIP layout (central dir) ===")
    z=parse_zip(dec)
    print("entries=%d cd_abs=%#x cdoff=%#x cdsize=%d eocd=%#x"%(z["ntot"],z["cd_abs"],z["cdoff"],z["cdsize"],z["eocd"]))
    for e in z["entries"]:
        print("  lho=%#010x csize=%-9d usize=%-9d meth=%d fl=%#x %s"%(e["lho_abs"],e["csize"],e["usize"],e["method"],e["flags"],e["name"]))
    print("\n=== check_word sanity ===")
    scw,sl,ct=struct.unpack_from("<III",dec,0); body=dec[0x34:]
    print("stored cw=%08x len=%d | computed cw=%08x len=%d"%(scw,sl,check_word(body),len(body)))
    print("\n=== ROUND-TRIP TEST ===")
    rp=confuse(dec); rh=rebuild_header(orig[:HDR],dec,rp)
    print("payload==orig[112:]:",rp==orig[HDR:]," header==orig[:112]:",rh==orig[:HDR]," FULL==orig:",(rh+rp)==orig)

def build(update_sh_path, out_path):
    import zipfile
    orig=open(ADS,"rb").read(); dec=_load_dec()
    new_sh=open(update_sh_path,"rb").read()
    new_dec=replace_update_sh(dec,new_sh)
    new_ads=make_ads(orig,new_dec)
    open(out_path,"wb").write(new_ads)
    # verify by decoding the repack
    rt=decode(new_ads)
    zf0=zipfile.ZipFile(io.BytesIO(dec[ZIP_BASE:])); zf1=zipfile.ZipFile(io.BytesIO(rt[ZIP_BASE:]))
    got=zf1.read("update.sh"); shok=(got==new_sh)
    print("OUT:",out_path,"| size",len(new_ads))
    print("update.sh in repack == input :", shok, "(%d bytes)"%len(got))
    ok=True
    for n in MEMBERS:
        s=(zf0.read(n)==zf1.read(n)); ok=ok and s
        print("  %-34s unchanged=%s"%(n,s))
    print("VERIFY:", "PASS" if (ok and shok) else "FAIL")

if __name__=="__main__":
    import sys
    if len(sys.argv)>1 and sys.argv[1]=="build":
        build(sys.argv[2], sys.argv[3])
    else:
        selftest()
