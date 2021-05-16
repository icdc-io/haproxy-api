require 'openssl'
require 'openssl-extensions/all'
require 'base64'

module CertHelper

  def cert(domain, san=[])
    key = OpenSSL::PKey::RSA.new(2048)
    public_key = key.public_key

    subject = "/C=BY/O=IBA Group, JV/OU=DOCSA/CN=#{domain}/emailAddress=hacker@tut.by"

    cert = OpenSSL::X509::Certificate.new
    cert.subject = cert.issuer = OpenSSL::X509::Name.parse(subject)
    cert.not_before = Time.now
    cert.not_after = Time.now + 365 * 24 * 60 * 60
    cert.public_key = public_key
    cert.serial = 0x0
    cert.version = 2

    # setup our certificate extensions. these may or may not match your need
    exts = [
      [ "basicConstraints", "CA:FALSE", false ],
      [ "keyUsage", "Digital Signature, Non Repudiation, Key Encipherment", false],
    ]

    unless san.empty?
      # SANs are just another extension, so we'll add them here
      san.map! do |item|
        "DNS:#{item}"
      end
      # add our subjectAltName extension containing our SANs
      exts << [ "subjectAltName", san.join(','), false ]
    end

    # use extension factory to generate the OpenSSL extension structures
    ef = OpenSSL::X509::ExtensionFactory.new
    exts.map do |ext|
      cert.add_extension ef.create_extension(*ext)
    end
    #attrval = OpenSSL::ASN1::Set([OpenSSL::ASN1::Sequence(exts)])
    #attrs = [
    #  OpenSSL::X509::Attribute.new('extReq', attrval),
    #  OpenSSL::X509::Attribute.new('msExtReq', attrval),
    #]
    #attrs.each do |attr|
    #  cert.add_attribute(attr)
    #end

    cert.sign key, OpenSSL::Digest::SHA256.new
    {cert: cert, key: key}
  end
    

  def cert_ob
    cert = "-----BEGIN CERTIFICATE-----
MIIDdTCCAl2gAwIBAgIJAJE7Y49Tt7XbMA0GCSqGSIb3DQEBCwUAMFExCzAJBgNV
BAYTAmJ5MQswCQYDVQQIDAJieTELMAkGA1UEBwwCYnkxCzAJBgNVBAoMAmJ5MQsw
CQYDVQQLDAJieTEOMAwGA1UEAwwFbWUubWUwHhcNMTgwMjI4MTMzODMxWhcNMTkw
MjI4MTMzODMxWjBRMQswCQYDVQQGEwJieTELMAkGA1UECAwCYnkxCzAJBgNVBAcM
AmJ5MQswCQYDVQQKDAJieTELMAkGA1UECwwCYnkxDjAMBgNVBAMMBW1lLm1lMIIB
IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAw8cbKzWI/pJAMxqmyg+wvV/g
jfWcgXc8v6+QqsWtTWRO3vYJN1Nt7Hl0V3WugiswdXrwHn2HAujPQvHuRmhjnrpG
5NjD2IgCW+57RLMelHPlZHaxz5AayqyUl8IScW6CvCQVt4nuqinunfHj3Cixo+WO
et+N6PV3pAIulKvtPtPnucC2KV7Z9hx1EFFhyG6HDeB8gfca09h9D/oyL3fi4fBw
u3Q0NEQ4M4XHWZnDn/lxSFVy7RoQSgWHGfQbNj1xY16mJSWmGUNIRm0/SiBctOBA
OjRrkC8FYFjHOqpvfV32Uat6zvgrj/LxXIpZH6+zA4/xQ5gF/myvjgbrqVZ/xQID
AQABo1AwTjAdBgNVHQ4EFgQU8UTpMOnUTHIiywiO8NGgY7Q76RowHwYDVR0jBBgw
FoAU8UTpMOnUTHIiywiO8NGgY7Q76RowDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0B
AQsFAAOCAQEAcLnfq+loomUwThyuDpdFkFaCAx9PL2P2VXZcTXwHzLzXSEdSYxqK
7jqp1u3tW+AEXoY248dj8gxIDJjEKWU6Vn1wUOqX0WeDkkOtPKWJ7tTbPkzFq1ms
opWGquJkZmb0zq5LsX5UPS9ASNjxNshb56gFwda23epJgXtMoWQDvgT210MjehCS
JQor7GCo/Nl5gHHJ7Ms/KQcsiYiKwiE3C3vlKFK5cUcUqGk7PxZb7+5eI/mzhtlO
j7DvqMsJzj/UPa5HK7zT4AOHyWsZUoHBraG7EYxIJgmqNPUmK+Vf1Dffe3eqCvOV
fRn1vwdyG2u04+uITHHYtrKZ+LRc/dinSg==
-----END CERTIFICATE-----"
    key="-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDDxxsrNYj+kkAz
GqbKD7C9X+CN9ZyBdzy/r5Cqxa1NZE7e9gk3U23seXRXda6CKzB1evAefYcC6M9C
8e5GaGOeukbk2MPYiAJb7ntEsx6Uc+VkdrHPkBrKrJSXwhJxboK8JBW3ie6qKe6d
8ePcKLGj5Y56343o9XekAi6Uq+0+0+e5wLYpXtn2HHUQUWHIbocN4HyB9xrT2H0P
+jIvd+Lh8HC7dDQ0RDgzhcdZmcOf+XFIVXLtGhBKBYcZ9Bs2PXFjXqYlJaYZQ0hG
bT9KIFy04EA6NGuQLwVgWMc6qm99XfZRq3rO+CuP8vFcilkfr7MDj/FDmAX+bK+O
BuupVn/FAgMBAAECggEBAIQnkBhvz+UANmQI1pPJWaXL5ZoONLJUGebPDVmpjJ2U
W4U4EeqN38LkDXvITZ9Cpjh3X0VFuPBm1Rm8k/plFvIbjiWGiVVOIkGKTx2Fx9uw
DCXv1YFmJh+vtbJnZ+m4DnoP5bT6X+fv3Eoz8Xs44QjguXgKFhIuOK+2ZVkoYUKp
ueCFnTCcqWfIYwxenV5NxLQfkkxpPcf/8SCx1GxeTkLQ6QZdsEXzajQjb9n3nFio
Mn24DJDLX2uN5LDtKcK4+xqHUkSqdln4mWA+VNshsWPNMdd/7dP/HVWV95cTM71V
Brfn29pbp6vtwP6hsfEALAw+4GFR9jbph2gtikgW7CECgYEA/OwyMOZsBf/BAsDY
OMe5qOPOQ/UdE3cmWwAlAOSFdiq/ADkyvkUG/KxrPARuar2qbsqyfQOauTgxPQVx
1IOy8NLPwSxi8FwZp6J08hwsvmvw9p/vYO+AcX5kRnOgDdj6Loh1IsUzEJ+c5zTG
NP0htcejYfyXtO+1MzdUjTvFWh0CgYEAxijqQnJHe3OQ+ZU5EVFs0qBN8A3M67A/
G+4UNCrpwKJjhlQ8P7h2sDJtouHmgBxgIcHOoDGiqUPamHN7W2W0wJSeNo8l72m2
UZgsJPb2d9ixCSVSIRYiy/ylymhpOjDXYFBClZK9RozXkJ6rFkWNYCIL0OpRlSgc
SIIpTR85i8kCgYAm47aP+E4x2fJ2lupoSKWOh4CmyGCxJof6RBpsebbfxZDa2vCn
evupDGXss4260fEL2hT5zf0Tb8V6aYToNVvlVbTmMgoAhVjYgs1SkOx8VyKU+WCY
Whs42ENY5dx9ZJiLYSYJs6K3cqNwlZfIfAeb6NeBcJJvGtCU0HQqxz8ALQKBgQCa
HhpMQYtc9X3sz2VKFdUYX7seF+2n5TTAKUOnazTQMLxNLliJipMs6JuikiVuwCL4
Pj7REqmbEf4CkdaAODMDkNMYRe9QLByzizHSMg1xGqReI5ujxg6cLkxXhytIKdJo
wyN2J2F0bHf/r5gKw194RCKCgque4UpWDn3G0KE2GQKBgDcWyZKDaiX/2tiVPg+Y
eZqU7ry6zmKKLJInCzWXNJqP/++UMM/ovvXMoV7/PDYNUpG0cMwek9PeRf9kf0Vn
RYAEOdTgMEi65BIBIOFwWel6ww+uVHCGombL/Iu+jh2Px93PBWaC5lJGADYTiPxO
x0If3DDryrzwVs5vU+PwsO5z
-----END PRIVATE KEY-----"
    {cert: cert, key: key}
  end

  def bad_cert_whitespaces
    cert = "  -----BEGIN CERTIFICATE-----  
        MIIF9zCCA9+gAwIBAgIJAK5z7d9YxdyzMA0GCSqGSIb3DQEBCwUAMIGRMQswCQYD
VQQGEwJCWTEOMAwGA1UECAwFTWluc2sxDjAMBgNVBAcMBU1pbnNrMRQwEgYDVQQK
DAtJQkEgSVQgUGFyazENMAsGA1UECwwEMkRlcDEYMBYGA1UEAwwPd2hpdGVzcGFj
ZS50ZXN0MSMwIQYJKoZIhvcNAQkBFhRhZG1pbkB3aGl0ZXNwYWNlLmNvbTAeFw0x
ODEwMDgwODMzMzhaFw00NjAyMjIwODMzMzha\r\r\r\r\r\r\r\r\r\r\r\r\r\rMIGRMQswCQYDVQQGEwJCWTEOMAwG
A1UECAwFTWluc2sxDjAMBgNVBAcMBU1pbnNrMRQwEgYDVQQKDAtJQkEgSVQgUGFy
azENMAsGA1UECwwEMkRlcDEYMBYGA1UEAwwPd2hpdGVzcGFjZS50ZXN0MSMwIQYJ
KoZIhvcNAQkBFhRhZG1pbkB3aGl0ZXNwYWNlLmNvbTCCAiIwDQYJKoZIhvcNAQEB
BQADggIPADCCAgoCggIBAMgg4IEHh3eGW7uml5gpvczGktiKMoaksba/DnXMmrK8
GUSYrxuCkxrSpQEYLVG8v3ZwTDVe8eP1aUsjl5MVBLqQlqJqmC5A8gJ0pa4sjn9r
K7iOzaXGUhYCxFUOjY180M8FUkehJfG0vyXmyqiw     NTsT1tr6MEE/TKE90u4h7Wuc
w4K7hPC8ogcw6VZCr+YKQ5oSVsfmmpBy2qwKIM9L5WVWFyhPLhfUqXzyM5kpztZT
5xOmDabhvAuVdsLBpEoQz6W8lyGf4f/PvFwv8mAPZDQmIBuXKqS8c8ek7dblxTqC
Cz/OH6RMSUw55VRUFa3KqM0dypYY9fXoKkqVeZPOeTQaQGZhy58WRgLQd5jb268q
mcmactVFfZBDdnBFC8r+x4JXtjCDpgzE5+u7SlhYwfdm+qdW/ff+kyz5H7Jl84Gk
toTq58rrHuuSjeWfcOXLxffTN9mQbGnrNrSYn6I4RJcJCRfuSJ7f9WSsoqorrj3b
BmbW7QHxGXm1rf6TsFUPNja/WHZMa+BbfxaZJ8/p69Gbg9lRQ7xxuj3FRuig6dOD
ClCMGNnIt2IMB3SZMVV4N6Dd2/r7i+LxPEV75CjrYZ/n6Iuaig5KDhUkxMAaqmIY
49e7W55WaAWSmz8qAjNnYvWUyvbAKfURhWBeYfVTXYm+femyj/sqpO0vjsMwUW2f
AgMBAAGjUDBOMB0GA1UdDgQWBBRc6u23Sfpyo+SwDGj4knLS6KWYxDAfBgNVHSME
GDAWgBRc6u23Sfpyo+SwDGj4knLS6KWYx    DAMBgNVHRMEBTADAQH/MA0GCSqGSIb3
DQEBCwUAA4ICAQAaABT9w/YEQETbK6uPe5HOSAMVN60PzLKgUbJmA11wP9N5dLC2
wte8p16a1baPwKpmpRRcj6vACERmF9SXVif9VjQqiNlVvxlNEL7NkRGvJ0JeHSqB
WHA6Z9MHNbjZcWcKiT8pBG1IdZfxcc308+ZrOKsOY0qdcd6ngUKMDdvhPjuLqDjw       
m54XW8AWmTn9RJmlEZywUKlEAYJcs4J/1z2XIo5hdn8aSn4CkvfZNaj8c/3xFKoh
l00Q6feOToTpUs1y2o/sUxN7g9YL4LWv1GT0BusXATW3\r\r\r\r\rFYFCFbZ/OxzUOgbZi1rK
thbyr2x17tpYH1dDWEyluCF8gm6aJG31xY8u9E74qYl/Rz33+OqW8eOeZ/SgOyAK
R8pb4OzwpJ1CWunu3a6tq/fosNLg6yeYZWqCELAWHcQxtFBmLCr9LAolYzwnr9R7
/9x4Mvglk4C2oJ/fP/bH2S0aGEaGVHcAKurzoieuooOrnRXXiXDPwcAH7Ne3DQQS
MGX4xRdk1QoPazHYYkC1hIJOnmwdJgTPAYMbCY5EvPu9WWPyTDAXo0v4biBVNNl4
MwhK34Jqxo/ij5E8NbyPPEVQlA2nHeQKCNDH8xDe+AIJyn1gZDiPf0rV/D/12YgK
  dknOlZgqfgb/1K2VU3iaCiSJ6V711eJc63CfcumUpzgPQn8HD7nkHRnSqA==  
   -----END CERTIFICATE-----   "
    key = "  -----BEGIN PRIVATE KEY-----  
\r\r\r\r\r\rMIIJQwIBADANBgkqhkiG9w0BAQEFAASCCS0wggkpAgEAAoICAQDIIOCBB4d3hlu7
ppeYKb3MxpLYijKGpLG2vw51zJqyvBlEmK8bgpMa0qUBGC1RvL92cEw1XvHj9WlL      
I5eTFQS6kJaiapguQPICdKWuLI5/ayu4js2lxlIWAsRVDo2NfNDPBVJHoSXxtL8l
5sqosDU7E9ba+jBBP0yhPdLuIe1rnMOCu4TwvKIHMOlWQq/mCkOaElbH5pqQctqs
CiDPS+VlVhcoTy4X1Kl88jOZKc7WU+cTpg2m4bwLlXbCwaRKEM+lvJchn+H/z7xc
L/JgD2Q0JiAblyqkvHPHpO3W5cU6ggs/zh+kTElMOeVUVBWtyqjNHcqWGPX16CpK
lXmTznk0GkBmYcufFkYC0HeY29uvKpnJmnLVRX2QQ3ZwRQvK/seCV7Ywg6YMxOfr
u0pYWMH3ZvqnVv33/pMs+R+yZfOBpLaE6ufK6x7rko3ln3Dly8X30zfZkGxp6za0
mJ+iOESXCQkX7kie3/VkrKKqK6492wZm1u0B8Rl5ta3+k7BVDzY2v1h2TGvgW38W
mSfP6evRm4PZUUO8cbo9xUbooOnTgwpQjBjZyLdiDAd0mTFVeDeg3dv6+4vi8TxF
e+Qo62Gf5+iLmooOSg4VJMT    AGqpiGOPXu1ueVmgFkps/KgIzZ2L1lMr2wCn1EYVg
XmH1U12Jvn3pso/7KqTtL47DMFFtnwIDAQABAoICAHfbSNm9+qHY9AOUqGHXTfbg
Tn4ldlExPcXm8vAWE+hLww5UKztcnmGIGo5nPm0fj8ONSfcE3/XYurDnphXOlsBt
a+nl0TKSbt6NodSIluc09kBYNk2    8Utkf2xnd12UPhbcWxspjduglif1XFbSlo5u4
LAuFn3TURj6jWjqIUzsJ7gXT7LCJKLkJ0BV7ZwFs0EPsC9E5CQTN5Kz4e+Hq4H4q
a0AW+9IF6WQNYl2urlOqeFBKOQ7jTs3ZPAE0HALHwrTOF+1pZd7hOTw08wIY9bhN
xRkBFecHfofo/RChF9gMnlQeTNEHZzahzfkNStaE80e1OelfFZ+q5fk5QFEHbYp4
rp3tfCeWNs8zjGfj6cWUNxSVGiFuIOK835Iz91zYkow8j+5LxczrOIlqlQTdjCaI
F0QzQtRxovmN/8plsCxUSI2qjK7C2tXXLwLBGQXVHyelQHYoG2O13dZ0zdTnkOZk
HsZdAXzS2ulRYYZR9ik+1AhiMjVjV5IybWq/FvU3iTIYock95XSmwynGY0R2b26Y
ShBh3mp77AfHD71c5hzmZUDONDbNhJUeQ7rUm+P2KYZt+ZykZGToi8sSLMtQsK7o
spyW0FYG3Vw4sSgDemK/6qScMWOzVCGlecgYEkmN93WGyI7vZZBnMhXdoI7e+cLE
aVBKSVq6CQEgialjqWZBAoIBAQD2/wqCXsVMaf1THiW6xPq7KDBChKUYgHp6/uYO
VC/MkgGYajBGGdDXVzoXxObx1+gYotsvIz3OGlvznkqjwAC7cTsJ5NCj9Yvoe9IM
UheLs25MBGUvXVE78Ru0GnXmvuwF5Vp1BjmIzb3qg+cXfl98cq04MxEeCIlhYUj2
u71HQe3kH1dngLx8E6mcKm/U93gmloRJSbKSr9PSPw1KNsU4fcdAFrzZmwlIFIm7
7Vg+Z0WvmxJkPBv6sCsi7AIYB/HwBnhi1AEM3bsX2zw5sxWc1qG/vrli0OWpztC7
v8F2KNLxnp7JfcospORdjUTJRZ07gZ81MfoS+Lj26GbmgasPAoIBAQDPbHeeME3H
UCybp5B6PNMNEfobZh3cBNCb9PGK/PIqMMaHTvTavAMMA8uQaHl8Z7e/ywS2rEBZ
kPDyw8KyIGSj/4bG5ONmmgkFpq5IY6zNktoQEGhcgmYR6wAfkjg4Esw0Pq/lS6vy
1KkeEOJw/v7ow1fMFBg1geUVui9a3EaZ9NJi8+uDfztTUm3GGrhX7ROu3ei47zI6
n5SmcvaO/YCprqCFEljSztg+oLC1l6CYjAmubevg1lLY2mzUIx+05CaEcQ+5tRtl
yaGw4vz+XavTUueXraTv4wL9+UFgKz2/zr4WkKiG9+6LeqoazMFYCYmRPiKuJKqt
EvYvKUobzFRxAoIBAQCZDhPSE64JGwi6j8zrfpKslUvKfG3d0AeV3gxrRqnUB4nr
i6ncVrT+K/Q4tHAz3wnY8loGTL1I0Ta3sRgpfpo1jQX7rInJgCgxaUERF3G1xPuN
KZAWGKp1DYSQR3FWCmsxgB1ctP3EE1IjV5dFDK9Y66sBT0vFI58V8/YFxvKUjHtA
yFceMT0bWgfZWMax3qParZzN2VhJ46DMAPxYR7ZQukhVI4HlClhnDSsIhBwRl2cs
WVi9Oi5QWwhv/HWTtKCsjyXcf+kisufz8YvRaXL0HGBg9GvmmvImFp1sKnhUoxmM
VjGpRESbA5brjdXZL0UukbU5fn2rcesUPZE+N43rAoIBAEYjpns+WD6qlLr5uXgs
My27Q3iaWkR4+FWUSU03ZWfw4GEGyPNiGiGo8t/dBB+WLuNS8kAXFRd0VJWyrpZv
L7jpAhklcuPR+HUJvOtLkTZejxBZjACkM4GhloQWfJ4xdQ3BmNcPdJCDasB48ylE
gMwSqhCfRuRpDR8Au1ydGd6bk7zUQHJRxqzRNb+Eb4uD5mD+NuC6OaDrL2ftfgQy
Ipy+KRd2ccSvHx5mVfrB0BNlXyy1jMqVjqQ3kA9X5TPU5lVoqemhHSeZO+zFhMk6
wYyO/zMiC6D2gZ+B9qJfXN0MOukEd4hUNDzD+NthG4v6haMwgKekTHaD7+1Yp++o
c3ECggEBAId5fFFLmIaf27qT6lHpZ2UzVBGklPGp8IfHoG54eMApZtyxaZEwQD1q
WjVUG5t6G5avofivyzJGaQH99/aHn3AKZi0frTHjtO/CTE8p7SJvS5gkVmvNczke
kV4JYicWEpZEe9fPAgLzyjyFVU5768S6YWICLOpJD3mXOrSMVp5BDLUbtKiXxuWx
IL1Y1JbVXYlJOptUuHIIa9ATuotLX2+EyILl0CXzX+iEB1Vt1kEQqqyxA4+6a6Nz
6MwEWF81sAq4Z2C80tMbNmaJc+deGxrx8ePKinExtC6IOje+YD0oWNsoETZG1L9U
  HAvCjoH7SEVViwDCL6SqJMd3zEPVwHE=   
    -----END PRIVATE KEY-----  "
    {cert: cert, key: key}
  end 

end
