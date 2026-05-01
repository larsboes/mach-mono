#!/usr/bin/env ruby
require 'xcodeproj'
require 'fileutils'

def find_or_create_group(parent_group, path_components)
  return parent_group if path_components.empty?

  group_name = path_components.shift
  # Try to find existing group
  group = parent_group.groups.find { |g| g.display_name == group_name || g.path == group_name }
  
  # Create if it doesn't exist
  unless group
    group = parent_group.new_group(group_name, group_name)
  end

  find_or_create_group(group, path_components)
end

def add_files(project_path, target_name, file_paths)
  project = Xcodeproj::Project.open(project_path)
  target = project.targets.find { |t| t.name == target_name } || project.targets.first

  file_paths.each do |file_path|
    puts "Adding #{file_path} to project..."
    
    # Split the path to find the right group
    # E.g., "boringNotch/MediaControllers/Browser Extension/File.swift"
    components = file_path.split('/')
    filename = components.pop
    
    # Find or create the group hierarchy
    group = find_or_create_group(project.main_group, components)
    
    # Check if file already exists in the group
    file_ref = group.files.find { |f| f.path == filename }
    
    unless file_ref
      # Add file reference to the group
      file_ref = group.new_file(filename)
    end
    
    # Add to the target's source build phase if it's a Swift file
    if file_path.end_with?('.swift') && !target.source_build_phase.files_references.include?(file_ref)
      target.add_file_references([file_ref])
      puts "  -> Added to target #{target.name}"
    else
      puts "  -> Already in target or not a compilable source"
    end
  end

  project.save
  puts "Project saved successfully."
end

def remove_files(project_path, target_name, file_paths)
  project = Xcodeproj::Project.open(project_path)
  target = project.targets.find { |t| t.name == target_name } || project.targets.first

  file_paths.each do |file_path|
    puts "Removing #{file_path} from project..."
    
    # We simply search all file references
    file_ref = project.files.find { |f| f.real_path.to_s.end_with?(file_path) || f.path == File.basename(file_path) }
    
    if file_ref
      # Remove from all build phases
      target.build_phases.each do |phase|
        phase.remove_file_reference(file_ref)
      end
      # Remove from group
      file_ref.remove_from_project
      puts "  -> Removed reference"
    else
      puts "  -> Could not find reference in project"
    end
  end

  project.save
  puts "Project saved successfully."
end

if ARGV.length < 2
  puts "Usage: ruby manage_xcode_files.rb [add|remove] file1.swift file2.swift ..."
  exit 1
end

command = ARGV.shift
files = ARGV
project_path = "boringNotch.xcodeproj"
target_name = "boringNotch"

case command
when "add"
  add_files(project_path, target_name, files)
when "remove"
  remove_files(project_path, target_name, files)
else
  puts "Unknown command: #{command}"
  exit 1
end
