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


def strip_empty_entries(hash)
  return hash unless hash.is_a?(Hash)

  hash.inject({}) do |m, (k, v)|
      m[k] = strip_empty_entries(v) unless v&.empty?
      m.delete(k) if m[k].nil? || m[k].empty?
      m
  end
end

def strip_packages_hash(hash)
  return hash['packages'] if hash['packages']

  hash.each_key do |key|
      next unless hash[key].is_a? Hash

      hash[key] = strip_packages_hash(hash[key])
  end
end

def strip_deps_uri(uri)
  python_version = Autoproj.workspace.config.get('python_version', nil)
  ros_hash = {:python3_pkgversion => "3", :__isa_name => "non-existant"}
  data = URI.open(uri).read
  data = data % ros_hash
  data = YAML.load(data).delete_if do |key|
      ['cmake', 'mercurial', 'git', 'python', 'python-setuptools'].include? key
  end

  data.each_key do |key|
      data[key].update(strip_packages_hash(data[key]))
      data[key].each_key do |pkg|
          next unless data[key][pkg].is_a? Hash
          next unless data[key][pkg].key? '*'

          data[key][pkg]["default"] = data[key][pkg]['*']
          data[key][pkg].delete('*')
      end
  end

  data = strip_empty_entries(data)
rescue SocketError
  Autoproj.warn("Cannot get dependencies packages from rosdep in #{uri}")
  nil
end

def strip_dist_uri(uri, ubuntu_distro, ros_distro)
  osdeps = {}
  distrib_file = URI.open(uri).read
  distrib = YAML.load(distrib_file)
  
  distrib['repositories'].each do |key, value|
      next unless value.has_key?('release')
      if value['release'].has_key?('packages')
          value['release']['packages'].each do |pkg|
              osdeps[pkg] ||= {}
              osdeps[pkg]['ubuntu'] ||= {}
              osdeps[pkg]['ubuntu'].merge!({ ubuntu_distro => "ros-#{ros_distro}-#{pkg.tr('_', '-')}" })
          end
      else
          pkg = key
          osdeps[pkg] ||= {}
          osdeps[pkg]['ubuntu'] ||= {}
          osdeps[pkg]['ubuntu'].merge!({ ubuntu_distro => "ros-#{ros_distro}-#{pkg.tr('_', '-')}" })
      end
  end
  osdeps
rescue SocketError
  Autoproj.warn("Cannot get ros distro packages from #{uri}")
  nil
end
