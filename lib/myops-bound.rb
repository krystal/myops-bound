class MyOpsBound < ::Rails::Railtie
  initializer 'myops.bound.initialize' do
    require 'my_ops/reverse_dns_providers/bound'
  end
end
