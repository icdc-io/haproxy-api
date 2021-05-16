require File.expand_path '../spec_helper.rb', __FILE__

def api(route)
  "#{@apiv}#{route}"
end
  

describe "API v1" do

  before(:all) do
    DatabaseCleaner[:mongoid].clean
    ApiKey.new.save!
    header 'X_HAPROXYAPI_KEY', ApiKey.last.value
    header 'CONTENT_TYPE', 'application/json'
    @apiv = "/api/1"
  end

  it "should allow accessing the root page" do
    get '/'
    expect(last_response).to be_ok
    expect(last_response).to match(/ICDC HAProxy API/)
  end

  context "Certificate API" do
    before(:each) do
      @count = Cert.all.count
    end

    it "get all certificates" do
      get api("/certs")
      expect(last_response).to be_ok
      expect(last_response.body).to eq("[]") 
    end

    it "create certificate" do
      c = cert("icdc.io")
      data = {name: "test cert",
              owner: "test@user.com",
              key: Base64.encode64(c[:key].to_pem),
              cert: Base64.encode64(c[:cert].to_pem)
             }
      post api("/certs"), data.to_json 
      @last = Cert.last
      expect(last_response.status).to eq(201)
      expect(Cert.all.count).to eq(@count+1)
      expect(@last.name).to eq(data[:name])
      expect(@last.owner).to eq(data[:owner])
    end

    it "create certificate, that not included base64 symbols" do
      bad_cert = bad_cert_whitespaces()
      data = {name: "Yahor Chyzheuski",
              owner: "ychyzheuski@ibagroup.eu",
              key: Base64.encode64(bad_cert[:key]),
              cert: Base64.encode64(bad_cert[:cert]),
              filename: "bad_whitespaces"}       
      post api("/certs"), data.to_json 
      @last = Cert.last
      expect(last_response.status).to eq(201)
      expect(Cert.all.count).to eq(@count+1)
      expect(@last.name).to eq(data[:name])
      expect(@last.owner).to eq(data[:owner])
    end
   
    it "create certificate custom 1" do
      c = cert_ob()
      data = {name: "test cert",
              owner: "test@user.com",
              key: Base64.encode64(c[:key]),
              cert: Base64.encode64(c[:cert]),
              filename: "custom1.pem"}
      post api("/certs"), data.to_json
      @last = Cert.last
      expect(last_response.status).to eq(201)
      expect(Cert.all.count).to eq(@count+1)
      expect(@last.name).to eq(data[:name])
      expect(@last.owner).to eq(data[:owner])
    end
  end

  context "Nodes API" do
    before(:each) do
      @count = HaproxyNode.all.count
    end

    it "should add node by host and name" do
      data = {name: "hap01", host: "h01.icdc.io"}
      post api('/nodes'), data.to_json
      expect(last_response).to be_ok
      expect(HaproxyNode.all.count).to eq(@count+1)
      @last = HaproxyNode.last
      expect(@last.name).to eq(data[:name])
      expect(@last.host).to eq(data[:host])
      expect(@last.port).to eq(22)
      expect(@last.user).to eq("haproxy")
    end
 
    it "should specify config and cert directories" do
      data = {name: "hap01", host: "h01.icdc.io", cert_dir: "/etc/ssl/custom_certs", config_dir: "/etc/custom_haproxy"}
      post api('/nodes'), data.to_json
      expect(last_response).to be_ok
      expect(HaproxyNode.all.count).to eq(@count+1)
      @last = HaproxyNode.last
      expect(@last.cert_dir).to eq(data[:cert_dir])
      expect(@last.config_dir).to eq(data[:config_dir])
    end


    it "should not allow without name" do
      data = {host: "h01.icdc.io"}
      post api('/nodes'), data.to_json
      expect(last_response).not_to be_ok
      expect(HaproxyNode.all.count).to eq(@count)
    end
    
    it "should not allow without host" do
      data = {name: "hap01"}
      post api('/nodes'), data.to_json
      expect(last_response).not_to be_ok
      expect(HaproxyNode.all.count).to eq(@count)
    end

  end

  context "Routes API" do
    before(:each) do
      @count = Route.all.count
    end
    
    it "should add web route" do
      rnd = Random.new.rand(10000)
      servers = [ {name: "my-srv1", host: "172.20.140.13", port: 8080} ]
      backend = { proto: "http", balance: "roundrobin", servers: servers }
      data = {name: "my lb 1", proto: "http", host: "test-vr.icdc.io", service_id: 2000000001924, backend: backend}
      post api('/routes'), data.to_json
      expect(last_response).to be_ok
      expect(Route.all.count).to eq(@count+1)
      @last = Route.last
      expect(@last.name).to eq(data[:name])
      expect(@last.host).to eq(data[:host])
      expect(@last.port).to eq(80)
      expect(@last.service_id).to eq(data[:service_id])
    end

    it "id format in json" do
      route = JSON.parse(last_response.body)
      expect(route["id"]).to match(/^[a-z0-9]{24}$/)
    end

    it "should not allow duplicated routes" do
      servers = [ {name: "my-srv1", host: "172.20.140.20", port: 9080} ]
      backend = { proto: "http", balance: "roundrobin", servers: servers }
      data = {name: "my lb 1 duplicate", proto: "http", host: "test-vr.icdc.io", service_id: 2000000001925, backend: backend}
      post api('/routes'), data.to_json
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(409) #Conflict
      expect(Route.all.count).to eq(@count)  
    end

    it "suspends the route" do
      rnd = Random.new.rand(10000)
      servers = [ {name: "my-srv1-#{rnd}", host: "172.20.140.13", port: 8080} ]
      backend = { proto: "http", balance: "roundrobin", servers: servers }
      project = { code: "1-123-#{rnd}", name: "Test #{rnd} project" }
      security = { status: "approved", purpose: "demo #{rnd} of test project", project: project }
      data = {name: "test #{rnd} route", proto: "http", host: "test-#{rnd}-route.icdc.io", service_id: 2000000001924+rnd, backend: backend, security: security}
      route = Route.create!(data)
      expect(route.security.status).to eq security[:status]

      put api("/routes/#{route.id}/suspend"), {}.to_json
      expect(last_response).to be_ok
      route.reload
      expect(route.security.status).to eq "suspended"
    end

    it "security options" do
      rnd = Random.new.rand(10000)
      servers = [ {name: "my-srv1-#{rnd}", host: "172.20.140.13", port: 8080} ]
      backend = { proto: "http", balance: "roundrobin", servers: servers }
      project = { code: "1-123-#{rnd}", name: "Test #{rnd} project" }
      security = { status: "approved", purpose: "demo #{rnd} of test project", project: project }
      data = { security: security, name: "test #{rnd} route", proto: "http", host: "test-#{rnd}-route.icdc.io", service_id: 2000000001924+rnd, backend: backend}
      post api('/routes'), data.to_json
      expect(last_response).to be_ok
      @last = Route.last
      expect(@last.security.status).to eq security[:status]
      expect(@last.security.purpose).to eq security[:purpose]
      expect(@last.security.project.code).to eq project[:code]
      expect(@last.security.project.name).to eq project[:name]
    end
    
    it "set-path the route" do
      rnd = Random.new.rand(10000)
      servers = [ {name: "my-srv1-#{rnd}", host: "172.20.140.13", port: 8080} ]
      backend = { proto: "http", balance: "roundrobin", servers: servers }
      project = { code: "1-123-#{rnd}", name: "Test #{rnd} project" }
      security = { status: "approved", purpose: "demo #{rnd} of test project", project: project }
      data = {name: "test #{rnd} route", proto: "http", host: "test-#{rnd}-route.icdc.io", service_id: 2000000001924+rnd, backend: backend, security: security}
      put_data = {path: "/landing"}
      route = Route.create!(data)

      put api("/routes/#{route.id}/set-path"), put_data.to_json
      expect(last_response).to be_ok
      route = Route.last
      expect(route.backend.opts).not_to be_empty
      expect(route.backend.opts.first.name).to eq "http-request"
      expect(route.backend.opts.first.value).to match(put_data[:path])
    end

  end

end

def router_cfg
  m = ConfigManager.new
  m.views = File.join(Sinatra::Application.settings.root, "..", "views")
  m.cfg_local = File.join(Sinatra::Application.settings.root, "..", "spec" , "router.cfg")
  m.generate_config
  content = File.read(m.cfg_local)
  File.delete(m.cfg_local)
  content
end

describe "Generate haproxy config" do
  
  before(:each) do
    DatabaseCleaner[:mongoid].clean
    @s1 = Server.new(name: "hacfg-backend-1", host: "127.0.0.1", port:3000)
    @s2 = Server.new(name: "hacfg-backend-2", host: "127.0.0.2", port:3000)
    @b = Backend.new(proto: "https", servers: [@s1, @s2])
    @sec = { status: "approved", purpose: "protocol project" }
    @r = Route.new(name: "protocol_route", host: "127.0.0.100",
                  proto: "https", service_id: 2000000001924,
                  backend: @b,
                  security: @sec
                 )
  end
  
  it "HTTPS-HTTPS route" do
    @r.proto = "https"
    @r.backend.proto = "https"
    @r.save!
    @cfg = router_cfg
    expect(@cfg).to match(/frontend.*mode http.*alpn h2,http\/1.1\s.*backend/m)
    expect(@cfg).to match(/backend.*mode http\s/m)
    expect(@cfg).to match(/server.*ssl verify none.*alpn h2,http\/1.1/)
  end
  
  it "HTTPS-HTTP route" do
    @r.proto = "https"
    @r.backend.proto = "http"
    @r.save!
    @cfg = router_cfg
    expect(@cfg).to match(/^\s*frontend.*mode http.*alpn h2,http\/1.1\s.*backend/m)
    expect(@cfg).to match(/^\s*backend.*mode http\s/m)
    expect(@cfg).not_to match(/^\s*server.*ssl verify none/)
  end
  
  it "HTTP-HTTPS route" do
    @r.proto = "http"
    @r.backend.proto = "https"
    @r.save!
    @cfg = router_cfg
    expect(@cfg).to match(/^\s*frontend.*mode http\s.*backend/m)
    expect(@cfg).to match(/^\s*backend.*mode http\s/m)
    expect(@cfg).to match(/^\s*server.*ssl verify none.*alpn h2,http\/1.1/)
  end

  it "HTTPS-HTTP/2 route" do
    @r.proto = "https"
    @r.backend.proto = "http2"
    @r.save!
    @cfg = router_cfg
    expect(@cfg).to match(/^\s*frontend.*mode http.*alpn h2,http\/1.1\s.*backend/m)
    expect(@cfg).to match(/^\s*backend.*mode http\s/m)
    expect(@cfg).to match(/^\s*server.*proto h2/)
  end

  it "HTTP-HTTP/2 route" do
    @r.proto = "http"
    @r.backend.proto = "http2"
    @r.save!
    @cfg = router_cfg
    expect(@cfg).to match(/^\s*frontend.*mode http\s.*backend/m)
    expect(@cfg).to match(/^\s*backend.*mode http\s/m)
    expect(@cfg).to match(/^\s*server.*proto h2/)
  end

  it "TCP-TCP route" do
    @r.proto = "tcp"
    @r.backend.proto = "tcp"
    @r.save!
    @cfg = router_cfg
    expect(@cfg).to match(/^\s*frontend.*mode tcp\s.*backend/m)
    expect(@cfg).to match(/^\s*backend.*mode tcp\s/m)
    expect(@cfg).not_to match(/^\s*server.*ssl verify none/)
  end
  
  it "TCP send-proxy" do
    @r.proto = "tcp"
    @r.backend.proto = "tcp"
    @opt1 = Opt.new(name: "send-proxy")
    @opt2 = Opt.new(name: "fake-option", value: "fake-value")
    @r.backend.servers[0].opts.push(@opt1, @opt2)
    @r.backend.servers[1].opts.push(@opt1, @opt2)
    @r.save!
    @cfg = router_cfg
    expect(@cfg).to match(/^\s*server.* #{@opt1.name}/)
    expect(@cfg).to match(/^\s*server.* #{@opt2.name} #{@opt2.value}/)
  end
  
  it "HTTP http-request set-path" do
    @r.proto = "http"
    @opt1 = Opt.new(name: "http-request", value: "set-path /landing")
    @r.backend.opts.push(@opt1)
    @r.save!
    @cfg = router_cfg
    expect(@cfg).to match(/http-request set-path \/landing/)
  end
  
  it "HTTPS http-request set-path" do
    @r.proto = "https"
    @opt1 = Opt.new(name: "http-request", value: "set-path /landing")
    @r.backend.opts.push(@opt1)
    @r.save!
    @cfg = router_cfg
    expect(@cfg).to match(/http-request set-path \/landing/)
  end

end
