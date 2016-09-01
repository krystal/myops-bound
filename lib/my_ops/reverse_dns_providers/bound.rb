module MyOps
  module ReverseDNSProviders
    class Bound < MyOps::ReverseDNSProvider

      self.provider_name = "Bound"
      self.provider_description = "Bound is a self hosted web interface on top of BIND and can provide support for publishing reverse DNS records."


    end
  end
end
