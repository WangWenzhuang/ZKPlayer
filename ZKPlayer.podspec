Pod::Spec.new do |s|
  s.name = 'ZKPlayer'
  s.version = '0.4'
  s.ios.deployment_target = '9.0'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.summary = '封装 AVPlayer，使用方便。'
  s.homepage = 'https://github.com/WangWenzhuang/ZKPlayer'
  s.authors = { 'WangWenzhuang' => '1020304029@qq.com' }
  s.source = { :git => 'https://github.com/WangWenzhuang/ZKPlayer.git', :tag => s.version }
  s.description = '封装 AVPlayer，使用方便。'
  s.source_files = 'ZKPlayer/*.swift'
  s.resources = 'ZKPlayer/ZKPlayer.bundle'
  s.requires_arc = true
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '4.0' }
  s.dependency 'Kingfisher'
end
