# https://github.com/Artoria/MyAPI
# Author: Seiran  
module API
  RMM = Win32API.new("Kernel32", "RtlMoveMemory", "pii", "i")
  
  module_function
  #traits:
  module Primitive;    end
  module Out;          end
  
  FUNC = Hash.new{|h, k| h[k] = {}}
  
  def init
    eval %{
      class Numeric
        include API::Primitive
      end
      
      class String
        include API::Primitive
      end
      
      class Integer
        def pack
          [self].pack("L")
        end
      end
      
      class String
        def pack
          [self].pack("p")
        end
      end
      
    },TOPLEVEL_BINDING
  end
  
  class OutL
    include Out
    def pack() "\0\0\0\0" end
    def unpack(packed, ofs); packed[ofs]; end
  end
    
  Out_Long = L = OutL.new
  
  def pack(args, inbuf)
    packed = ""
    inbuf << packed
    args.each_with_index{|x, i|
      case x
        when Primitive
          packed << x.pack
        when Out
          packed << x.pack
        when Array
          packed[i*4, 4] = [pack(x, inbuf)].pack('p')
      end
    }
    packed
  end
  
  def unpack(args, packed)
    unpacked = []
    args.each_with_index{|x, i|
      case x
        when Primitive
        when Out
          unpacked << x.unpack(packed, i)
        when Array
          ptr = packed[i]
          str = "\0"*(x.length*4)
          RMM.call str, ptr, str.length
          unpacked.concat unpack(x, str.unpack("L*"))
      end
    }
    unpacked
  end
  
  def api(func, name, *args)
    inbuf     = []
    packed    = pack(args, inbuf)
    packed    = packed.unpack("L*")
    func = FUNC[func][name] ||= Win32API.new(func, name, "i"*args.length, 'i')
    ret = func.call *packed
    unpacked  = unpack(args, packed)
    [ret, *unpacked]
  end
  
  init
end