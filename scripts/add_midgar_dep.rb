#!/usr/bin/env ruby
require 'xcodeproj'

# xcodeproj 1.27 rejects Xcode 16 synchronized-group *resource* membership exceptions; widen the
# allowed build-phase classes so projects using file-system-synchronized folders still open.
begin
  klass = Xcodeproj::Project::Object::PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet
  klass.attributes.each do |attribute|
    next unless attribute.name == :build_phase
    resources = Xcodeproj::Project::Object::PBXResourcesBuildPhase
    attribute.instance_variable_set(:@classes, (attribute.classes + [resources]).uniq) unless attribute.classes.include?(resources)
  end
rescue NameError
end

proj_path = ARGV[0]
target_name = ARGV[1]
url = 'https://github.com/guitaripod/MidgarKit'
product = 'MidgarKit'

project = Xcodeproj::Project.open(proj_path)
target = project.targets.find { |t| t.name == target_name }
abort("target not found: #{target_name}") unless target

pkg = project.root_object.package_references.find do |r|
  r.is_a?(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference) && r.repositoryURL == url
end
if pkg.nil?
  pkg = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  pkg.repositoryURL = url
  pkg.requirement = { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => '2.0.0' }
  project.root_object.package_references << pkg
end

if target.package_product_dependencies.any? { |d| d.product_name == product }
  puts "#{product} already linked in #{target_name}"
else
  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.package = pkg
  dep.product_name = product
  target.package_product_dependencies << dep

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dep
  target.frameworks_build_phase.files << build_file
  puts "linked #{product} into #{target_name}"
end

project.save
