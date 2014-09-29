#!/opt/puppet/bin/ruby

require 'etc'
require 'rubygems'
require 'yaml'
require 'mysql2'
require 'syslog/logger'
require 'puppet'
require 'puppet/ssl/certificate_request'

# Everyone needs a $HOME
ENV['HOME'] = Etc.getpwuid(Process.uid).dir

log = Syslog::Logger.new 'mysql-cert-autosign'
log.info "Policy-based auto-sign started."

clientcert = ARGV.pop.to_s
csr = Puppet::SSL::CertificateRequest.from_s(STDIN.read)

if csr.name != clientcert
  log.error "Node certname doesn't math CSR #{csr.name} != #{clientcert}"
  exit 1
end

cfg_file = File.join(File.dirname(__FILE__),"mysql-cert-autosign.yaml")

unless File.exist?(cfg_file)
  log.error "Missing config file #{cfg_file}"
  exit 2
end

cfg = YAML.load(File.read(cfg_file))
unless cfg.kind_of?(Hash)
  log.error 'Error parsing configurtion file #{cfg_file}'
  exit 3
end

db_user = cfg["db_user"]
db_pass = cfg["db_pass"]
db_name = cfg["db_name"]
db_host = cfg["db_host"]

log.debug "user: #{db_user}, pass: #{db_pass}, db: #{db_name}, host: #{db_host}"

db = Mysql2::Client.new(:username => db_user, :password => db_pass, :host => db_host, :database => db_name)

query = "update node set signed = '1' where certname = '#{clientcert}' and signed = '0'"
log.debug "Executing \"#{query}\""

db.query(query)
if db.affected_rows != 1
  log.error "Update query returned #{db.affected_rows} affected rows."
  exit 4
end

log.info "Accepted certificate request for #{clientcert}."
exit 0
