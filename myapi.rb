# https://github.com/Artoria/MyAPI
# Author: Seiran  
module API
  RMM         = Win32API.new("Kernel32", "RtlMoveMemory", "pii", "i")
  GA          = Win32API.new("Kernel32", "GlobalAlloc", "ii", "i")
  module_function
  #traits:
  module In;   
    def packlen() 4 end
  end
  module Out;  
    def packlen() 4 end
  end
  
  FUNC = Hash.new{|h, k| h[k] = {}}
  
  def init
    eval %{
      class Numeric
        include API::In
      end
      
      class String
        include API::In
      end
      
      
      class Integer
        def pack
          [self].pack("L")
        end
      end
      
      class Float
        def pack
          [self].pack("F")
        end
      end
      
      class String
        def pack
          [self].pack("p")
        end
      end
      
      class Array
        def allpacklen
          inject(0){|a,b| a+b.packlen}
        end
        def packlen
          4
        end
      end
      
    },TOPLEVEL_BINDING
  end
  
  class OutL
    include Out
    def initialize(value = 0)
      @value = value
    end
    def pack() [@value].pack("L") end
    def unpack(str); str.unpack("L").first end
  end
    
  class OutStr
    include Out
    def initialize(len)
       @len = len
       @str = "\0"*@len
    end
    def pack() [@str].pack('p')  end
    def unpack(str); @str end
    
  end
    
    
  Out_Long = L = OutL.new
  def pack(args, inbuf)
    packed = ""
    inbuf << packed
    args.each_with_index{|x, i|
      case x
        when In
          packed << x.pack
        when Out
          packed << x.pack
        when Array
          packed << [pack(x, inbuf)].pack('p')
      end
    }
    packed
  end
  
  def unpack(args, packed)
    unpacked = []
    index = 0
    args.each_with_index{|x, i|
      case x
        when In
        when Out
          unpacked << x.unpack(packed[index, x.packlen])
        when Array
          ptr = packed[index, 4].unpack("L").first
          str = "\0"*x.allpacklen
          RMM.call str, ptr, str.length
          unpacked.concat unpack(x, str)
          index += 4
      end
      index += x.packlen unless x.is_a?(Array)
    }
    unpacked
  end
  
  
  class CodeBegin
    include In
    def pack() [0x55, 0x89, 0xe5].pack("C*") end
    def packlen() 3 end
  end
    
  class CodeEnd
    include In
    def initialize(len = 16) @len = len end
    def pack() [0xc9, 0xc2, @len].pack("CCS") end
    def packlen() 4 end
  end
    
  class Call
    include In
    def initialize(addr) @addr = addr end
    def pack() [0xb8, @addr, 0xff, 0xd0].pack("CLCC") end
    def packlen() 7 end
  end
    
  class Balance
    include In
    def initialize(am) @am = am end
    def pack() [0x81, 0xc4, @am].pack("CCL") end
    def packlen() 6 end
  end
    
  class Emit
    include In
    def initialize(ch) @ch = ch end
    def pack() [@ch].pack("C") end
    def packlen() 1 end
  end
    
  
  def codebegin(*a); CodeBegin.new(*a)      end
  def codeend(*a);   CodeEnd.new(*a)        end  
  def call(*a);      Call.new(*a)           end  
  def balance(*a);   Balance.new(*a)        end
  def emit(*a);      Emit.new(*a)           end
  def push();        emit(0x68)             end
    
  def ccall(func, *a)  
       a.reverse.inject([]){|arr,x|arr << push << x}.concat  [call(func),balance(a.length*4)]
  end
     
  def cdecl(func, *a)  
       a.reverse.inject([]){|arr,x|arr << push << x}.concat  [call(func),balance(a.length*4)]
  end
  
    
  def stdcall(func, *a)  
       a.reverse.inject([]){|arr,x| arr << push << x}.concat [call(func)]
  end
     
  def function(*a)
    x = a.inject([]){|arr, y| arr.concat(y)}
    result = [codebegin].concat(x).concat [codeend]
    result
  end
    
  def api(func, name, *args)
    inbuf     = []
    packed    = pack(args, inbuf)
    func = FUNC[func][name] ||= Win32API.new(func, name, "i"*args.length, 'i')
    ret = func.call *packed.unpack("L*")
    unpacked  = unpack(args, packed)
    [ret, *unpacked]
  end
   
  def funcaddr(a,b)
    handle, = api "Kernel32", "GetModuleHandle", a
    handle, = api "Kernel32", "LoadLibrary", a if handle == 0
    func,   = api "Kernel32", "GetProcAddress", handle, b
    func
  end

  def capi(func, name, *args)
    addr = funcaddr(func,name)
    api "User32", "CallWindowProc", function(cdecl(addr, *args)), 0, 0, 0, 0
  end
  
  init
end

