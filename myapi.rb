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
        def pack(str, ofs)
          str[ofs, 4] = [self].pack("L")
        end
      end
      
      class String
        def pack(str, ofs)
          str[ofs, 4] = [self].pack("p")
        end
      end
      
    },TOPLEVEL_BINDING
  end
  
  class OutL
    include Out
    def pack(str, ofs); end
    def unpack(packed, ofs); packed[ofs]; end
  end
    
  Out_Long = L = OutL.new
  
  def pack(args, inbuf)
    packed = "\0"*(args.length*4)
    inbuf << packed
    args.each_with_index{|x, i|
      case x
        when Primitive
          x.pack(packed, i*4)
        when Out
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