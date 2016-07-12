Pod::Spec.new do |s|
  s.name         = "Event"
  s.version      = "0.1.0"
  s.license      = { :type => "Apache 2", :file => "LICENSE" }
  s.summary      = "Reactive Events Foundation"
  s.homepage     = "https://github.com/reactive-swift/Event"
  s.social_media_url = "https://github.com/reactive-swift/Event"
  s.authors = { "Daniel Leping" => "daniel@crossroadlabs.xyz" }
  
  s.source = { :git => "https://github.com/reactive-swift/Event.git", :tag => "#{s.version}" }
  
  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target = "9.0"

  s.source_files = "Event/*.swift"
  
  s.dependency 'ExecutionContext', '0.4.0'
  
  s.requires_arc = true

end
