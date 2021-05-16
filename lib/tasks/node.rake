namespace :node do
  desc "Configure specified remote HAProxy nodes with SSH-keys"
  task :config do
    if ARGV.count < 2 
      puts "Specify [user@]hostname of remote node and password"
      exit 1
    end
    host = ARGV.last
    puts "Config HAProxy Node: #{host}"
   
    begin
      sh "ssh-copy-id #{host}"
    rescue
      sh "ssh-keygen -P \"\""
    end
    
  end
end
