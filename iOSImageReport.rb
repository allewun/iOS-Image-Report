#!/usr/bin/ruby

#################################################
#  Find issues in an Xcode iOS project regarding
#  retina/non-retina, unused, and missing images
#
#    by Allen Wu (allen.wu@originate.com)
#    8/25/2012
#

require 'rubygems'
require 'trollop'

RED = "\e[31m"
GREEN = "\e[32m"
YELLOW = "\e[33m"

#################################################
#  Functions
#

def is_1x(img); return !(img =~ /@2x$/); end
def is_2x(img); return (img =~ /@2x$/); end
def colorize(text, color_code); "#{color_code}#{text}\e[0m"; end

class Hash
  def print_results(msg, color)
    puts colorize(msg, color) if self.count_images > 0

    self.sort.each do |file, img_array|
      puts "#{file}"
      img_array.sort.each { |img| puts "  #{img}.png" }
      puts
    end
  end
  def count_images
    self.reduce([]) { |a, (k,v)| a << v; a }.flatten.uniq.count
  end
end

class Array
  def print_results(msg, color)
    puts colorize(msg, color) if self.count > 0
    self.sort.each { |img| puts "  #{img}.png" }
    puts
  end
end

# from: http://www.ruby-forum.com/topic/82898
def format_bytes(n)
  index = ( Math.log(n) / Math.log(2) ).to_i / 10
  "~#{n.to_i / (1024 ** index)} " + ['B', 'KB', 'MB', 'GB'][index].to_s
end

################################################
#  Start...
#

opts = Trollop::options do
  version <<-EOS
  XcodeImageReport.rb v1.0
    Allen Wu (allen.wu@originate.com)
    Last updated: 8/25/2012
  EOS
  banner <<-EOS
  Find issues in an Xcode iOS project regarding
  retina/non-retina, unused, and missing images.
  EOS
  opt :dir, "Target directory",
      :type => :string,
      :required => true
end

directory = opts.dir

# all images
images_all = `find #{directory} -name "*.png"`.to_a.map { |x| x.sub(/^.*\//, '').sub(".png\n", '') }.sort

# all the 2x images
images_2x = images_all.select { |x| is_2x(x) }.map { |x| x.sub(/@2x$/, '') }

# all the 1x images
images_1x = images_all.select { |x| is_1x(x) }

# images that only have 2x version
images_2x_only = images_2x - images_1x

# images that only have 1x versions
images_1x_only = images_1x - images_2x

# images that have 1x and 2x versions
images_both = (images_all.map { |x| x.sub(/@2x$/, '') } - images_2x_only - images_1x_only).uniq



# start to gather all image references from code and nib files
code_files = `find #{directory} -maxdepth 1 -name "*.xib" -o -name "*.[hm]"`.to_a.map { |x| x.sub(/^.*\//, '').sub("\n", '') }
references_all = {}
references_noimg = {}
references_upscaled = {}
references_downscaled = {}
images_notused = {}

# create hash of files and their referenced images
code_files.each do |file|
  references_all[file] = []

  `grep -o "[^\\">/]*\\.png" #{directory}/#{file}`.each { |x| references_all[file].push x.sub(".png\n", '') }
end

# hash now contains code files as keys containing arrays of the images that they reference
references_all.each { |k,v| v.uniq! }

print "\n"

# each file
references_all.each do |file, imgs|
  references_noimg[file] = []
  references_upscaled[file] = []
  references_downscaled[file] = []

  # each image within the file
  imgs.each do |img|
    # bare image name (without @2x suffix)
    img_name = img.sub(/@2x$/, '')

    # only 1x image exists
    if (images_1x_only.include? img_name)
      # warn that retina devices will upscale the image
      if (is_1x(img))
        references_upscaled[file].push(img)

      # missing image
      else
        references_noimg[file].push(img)
      end

    # only 2x image exsits
    elsif (images_2x_only.include? img_name)
      references_downscaled[file].push(img)

    # both 1x and 2x versions exist
    elsif (images_both.include? img_name)
      # warn that non-retina devices will downscale the retina image
      if (is_2x(img))
        references_downscaled[file].push(img)
      end

    # missing image
    else
      references_noimg[file].push(img)
    end
  end
end



# clean-up
references_noimg.reject! { |k,v| v.empty? }
references_upscaled.reject! { |k,v| v.empty? }
references_downscaled.reject! { |k,v| v.empty? }

# array of all the images being referenced
images_used = references_all.reduce([]) { |a, (k,v)| a << v; a }.flatten.uniq.sort

# contains images that exist but aren't explicitly referenced (primarily @2x)
images_unused = images_all - images_used

# remove retina images that are indirectly referenced
images_unused = images_unused.select { |x| !(images_used.include? x.sub(/@2x$/, '')) }

# calculate file size of unused images
images_unused_space = format_bytes(images_unused.reduce(0) { |a,img| a + File.size("#{directory}/#{img}.png") })

# summary

time = Time.now.strftime("                          -- %m/%d/%Y %I:%M%p")

puts '**************************************************'
puts '                      RESULTS'
puts "  #{references_noimg.count_images} missing images"
puts "  #{references_upscaled.count_images} images that will be upscaled"
puts "  #{references_downscaled.count_images} images that will be downscaled"
puts "  #{images_unused.count} unused images (#{images_unused_space})"
puts
puts "  #{time}"
puts '**************************************************'
puts

# print results

references_noimg.print_results("[ERROR] These images are referenced but don't exist:", RED)
references_upscaled.print_results("[WARNING] These images will be upscaled on retina devices:", YELLOW)
references_downscaled.print_results("[WARNING] These images will be downscaled on non-retina devices:", YELLOW)
images_unused.print_results("[NOTICE] These images are unused:", GREEN)
