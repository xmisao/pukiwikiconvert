require 'fileutils'
require 'nkf'
require 'zlib'

PUKIWIKI_DIRS = ['wiki', 'backup', 'attach', 'diff', 'cache']

def has_pukiwiki_dir_struct(dir)
  PUKIWIKI_DIRS.each{|pd|
    return false unless FileTest.directory?("#{dir}/#{pd}")
  }
end

def is_empty_dir(dir)
  FileTest.exist?(dir) && Dir.glob("#{dir}/*").empty?
end

def create_pukiwiki_dir_struct(dir)
  PUKIWIKI_DIRS.each{|pd|
    FileUtils.mkdir("#{dir}/#{pd}")
  }
end

def convert_name_euc2utf(name)
  matches = name.match(/^([^\.]+)(\..+)?$/).to_a
  name_euc = matches[1]
  name_ext = matches[2]
  raise "Can't convert `#{name}`." unless name_euc

  name_euc.split('_').map{|euc|
    euc_str = [euc].pack('H*')
    utf8_str = NKF.nkf('-w', euc_str)
    utf8_str.unpack('H*')[0].upcase
  }.join('_') + name_ext.to_s
end

def get_file_info(path)
  open(path, 'rb'){|f|
    {content: f.read, mtime: f.mtime}
  }
end

def get_gz_file_info(path)
  result = nil
  open(path, 'rb'){|f|
    g = Zlib::GzipReader.new(f)
    result = {content: g.read, mtime: f.mtime}
    g.close
  }
  result
end

def src_path_to_dst_path(src_path, dst_dir)
  src_file = File.basename(src_path)
  dst_file = convert_name_euc2utf(src_file)
  dst_dir + '/' + dst_file
end

def convert_filename_euc2utf(src_path, dst_dir)
  dst_path = src_path_to_dst_path(src_path, dst_dir)
  FileUtils.cp(src_path, dst_path)
end

def convert_filename_and_content_euc2utf(src_path, dst_dir)
  info = get_file_info(src_path)

  dst_path = src_path_to_dst_path(src_path, dst_dir)

  open(dst_path, 'wb'){|f|
    f.print NKF.nkf('-w', info[:content])
  }
  File.utime(Time.now, info[:mtime], dst_path)
end

def convert_filename_and_compressed_content_euc2utf(src_path, dst_dir)
  info = get_gz_file_info(src_path)

  dst_path = src_path_to_dst_path(src_path, dst_dir)

  open(dst_path, 'wb'){|f|
    g = Zlib::GzipWriter.new(f)
    g.print NKF.nkf('-w', info[:content])
    g.close
  }
  File.utime(Time.now, info[:mtime], dst_path)
end

def each_file(dir, pattern, &blk)
  Dir.glob("#{dir}#{pattern}"){|path|
    STDOUT.puts "Processing... #{path}"
    begin
      blk.call(path)
    rescue => e
      STDERR.puts "Can't convert #{path} caused by #{e.inspect}. Skipped."
    end
  }
end

def main(argv)
  STDOUT.puts 'Start.'

  src_dir = argv[0]
  dst_dir = argv[1]

  raise "#{src_dir} is not pukiwiki's directory." unless has_pukiwiki_dir_struct(src_dir)
  raise "#{dst_dir} is not empty." unless is_empty_dir(dst_dir)

  create_pukiwiki_dir_struct(dst_dir)

  each_file(src_dir, "/wiki/*.txt"){|src_path|
    convert_filename_and_content_euc2utf(src_path, dst_dir + '/wiki')
  }

  each_file(src_dir, "/backup/*.gz"){|src_path|
    convert_filename_and_compressed_content_euc2utf(src_path, dst_dir + '/backup')
  }

  each_file(src_dir, "/diff/*.txt"){|src_path|
    convert_filename_and_content_euc2utf(src_path, dst_dir + '/diff')
  }

  each_file(src_dir, "/attach/*_*"){|src_path|
    convert_filename_euc2utf(src_path, dst_dir + '/attach')
  }

  each_file(src_dir, "/cache/*.*"){|src_path|
    convert_filename_and_content_euc2utf(src_path, dst_dir + '/cache')
  }

  STDOUT.puts 'Done.'
end

main(ARGV)
