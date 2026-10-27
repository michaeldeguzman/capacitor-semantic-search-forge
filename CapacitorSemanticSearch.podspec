require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name = 'CapacitorSemanticSearch'
  s.version = package['version']
  s.summary = package['description']
  s.license = package['license']
  repo_url = (package.dig('repository', 'url') || 'https://www.npmjs.com/package/capacitor-semantic-search').sub(/^git\+/, '')
  s.homepage = package['homepage'] || repo_url
  s.author = package['author']
  s.source = { :git => repo_url, :tag => s.version.to_s }
  s.source_files = 'ios/Plugin/**/*.{swift,h,m,c,cc,mm,cpp}'
  s.resource_bundles = {
    'SemanticSearchModel' => ['ios/Plugin/Resources/MiniLM.mlmodelc', 'ios/Plugin/Resources/vocab.txt', 'ios/Plugin/Resources/MiniLM-LICENSE.txt']
  }
  s.frameworks = 'CoreML'
  s.ios.deployment_target  = '14.0'
  s.dependency 'Capacitor'
  s.swift_version = '5.1'
end
