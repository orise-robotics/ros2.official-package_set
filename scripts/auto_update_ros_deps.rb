# Copyright 2021 Open Rise Robotics
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'yaml'
require 'open-uri'

require_relative 'helpers/strip.rb'

ws = Autoproj.workspace

ros_distro = ws.config.get('ros_distro',nil)
os_name, os_release = ws.operating_system


available_distro = Array.new
available_distro.push 'bionic'
available_distro.push 'focal'

ubuntu_distro = os_release[3]

raise Autoproj::ConfigError, 'ROS package sets can only be used with ubuntu' unless os_name.include? 'ubuntu'
raise Autoproj::ConfigError, 'This ubuntu distribution is not supported by ROS package sets. '\
    "\nSupported distributions: #{available_distro}" unless available_distro.include? ubuntu_distro


if osdeps = strip_dist_uri("https://raw.githubusercontent.com/ros/rosdistro/master/#{ros_distro}/distribution.yaml",
   ubuntu_distro, ros_distro)
  File.open(ROOT_DIR.join('ros.osdeps'), 'w') { 
      |file| file.write(osdeps.to_yaml(indentation: 4))
  }
end


files = ['base', 'python', 'ruby']
files.each do |file|
  data = strip_deps_uri("https://raw.githubusercontent.com/ros/rosdistro/master/rosdep/#{file}.yaml")
  # Hack to remove aliases
  data_json = data.to_json
  data_yaml = YAML.load(data_json)
  if data
    open(ROOT_DIR.join("#{file}.osdeps"), 'w') do |f|
        f.puts data_yaml.to_yaml
    end
  end
end
