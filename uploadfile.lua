local upload = require "resty.upload"
local dkjson = require "dkjson"
local uuid = require "resty.uuid"
local resty_string = require "resty.string"
local resty_jwt = require 'resty.jwt'
local chunk_size = 4096
local form,err = upload:new(chunk_size)
local conf = {max_size=1000000000, allow_exts={'jpg', 'png', 'gif'},system=nil , scope = 'private' }
local file
local file_name


local private_host = ngx.var.private_host or ''
local public_host = ngx.var.public_host or 'http://'..ngx.var.host


-- keys
local SIGNKEYS = {}
-- 知店
SIGNKEYS[1] = '38ac4ae0594511e6b21464006a444ba5'
SIGNKEYS[2] = 'ced7acd13e8d43d69c5704617ab03322'
SIGNKEYS[3] = '52260c28a5a743e1af595fa458fec9d1'
SIGNKEYS[4] = '283639a3876a4439af4af2b0c2366e9f'
SIGNKEYS[5] = '2e7d6279498f4036b7e12dcfb13ecd00'
SIGNKEYS[6] = '4b8addaa471b4c5394f62b1cc21bf299'
SIGNKEYS[7] = 'd61eb091929c460e9099ba74e8f59902'
SIGNKEYS[8] = '0fcf4de591614a23ace80b59d6a3e4b4'
SIGNKEYS[9] = 'f2ffc534422f4a8094e849ea9a79f175'
SIGNKEYS[10] = '244c7bbec76840fc9233566013ec421e'
SIGNKEYS[11] = '3e8578bc34b346db8aa5d52fc118c4b1'

-- 注：这个地方请将/home/data/upload换成你的项目目录
local upload_path = ngx.var.upload_path or '/home/data/upload'
ngx.log(ngx.NOTICE ,'upload path' ,upload_path )




method = ngx.req.get_method()
-- 解决跨域问题 ， 跨域请求首先会 预请求(method:options) ，需要服务直接返回200 ;
-- add_header Access-Control-Allow-Origin 'http://zd.dev.kashuo.net';
-- add_header 'Access-Control-Allow-Credentials' 'true';
-- add_header Access-Control-Allow-Method "POST, PUT, OPTIONS";
-- add_header  Access-Control-Allow-Headers "x-auth-appkey, x-auth-time, x-auth-token";
if method == 'OPTIONS' then
        ngx.exit(200)
end
--
if not form then
    ngx.log(ngx.ERR, "failed to new upload: ", err)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end




-- 获取post参数
function get_post_body()
    local data = ngx.req.get_body_data()
    if data then
        local obj, pos, err = dkjson.decode(data, 1, nil)
        if err then
            ngx.log(ngx.ERR , err , data)
        else
               return obj
        end
        end
end
-- 获取允许的文件扩展名
function get_allow_ext(args)
    local allow_exts = args.mimeType
    return allow_exts
end






-- 校验jwt

function verify_sign_jwt()
    local args = ngx.req.get_uri_args()
    ngx.log(ngx.DEBUG , 'ngx.req.get_uri_args : ' , dkjson.encode(args))
    if args == nil then
        ngx.say(dkjson.encode({code=10001 , msg='参数错误：sign  is required.'}))
        return
    end
    local jwt_token = args.sign
    if jwt_token == nil then
        ngx.say(dkjson.encode({code=10001, msg='参数错误：sign  is required.'}))
    end
    local jwt_obj = resty_jwt:load_jwt(jwt_token)

    ngx.log(ngx.NOTICE  , 'jwt obj : ' ,dkjson.encode(jwt_obj) )
    payload = jwt_obj.payload
    if payload== nil then
        ngx.say(dkjson.encode({code=10001 , msg='jwt参数错误:sys  is required.'}))
        return
    end
    system = payload.sys
    if system == nil then
        ngx.say(dkjson.encode({code=10001 , msg='jwt参数错误:sys  is required.'}))
        return
    end
    sys_key = nil
    for  k , v in pairs(SIGNKEYS) do
        if k == tonumber(system) then
            sys_key = v
        end
    end
    if sys_key == nil then
        ngx.say(dkjson.encode({code=10010 , msg='请联系管理员生成系统相关的key'}))
    end
    local verified = resty_jwt:verify_jwt_obj(sys_key, jwt_obj)
    -- ngx.say(dkjson.encode(verified))
    if verified.verified ~= true then
        ngx.say(dkjson.encode({code=10021 , msg='鉴权失败.'}))
        return
    end
    scope = payload.scope or 'private'
    max_size = tonumber(payload.max_size) or conf.max_size
    mime_type = payload.mime_type or conf.mime_type
    conf.system = system
    conf.scope = scope
    conf.max_size = max_size
    conf.mime_type = mime_type
    return true
end




--获取文件扩展名
function get_ext(res)
    local ext = 'jpg'
    if res == 'image/png' then
        ext = 'png'
    elseif res == 'image/jpg' or res == 'image/jpeg' then
        ext = 'jpg'
    elseif res == 'image/gif' then
        ext = 'gif'
    end
    return ext
end
--判断某个值是否在数组中
function in_array(v, tab)
    local i = false
    for _, val in ipairs(tab) do
        if val == v then
            i = true
            break
        end
    end
    return i
end


--获取文件名
function get_filename(res)
    local filename = ngx.re.match(res,'(.+)filename="(.+)"(.*)')
    if filename then
        return filename[2]
    end
end


--获取文件扩展名
function getExtension(str)
    if type(str)=='string' then
        return str:match(".+%.(%w+)$")
    else
        return nil
    end
end


while true do
    local typ, res, err = form:read()
    ngx.log(ngx.DEBUG , 'res:' , dkjson.encode(res))
    if typ == nil then
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    if typ == "header" then

        local verify_ret = verify_sign_jwt()
        if verify_ret~=true then
            break
        end

        if res[1] == 'Content-Disposition' then
            file_id = uuid()
            local filename = get_filename(res[2])
            local extension = getExtension(filename)
            local system_path = '/'..conf.scope..'/'..conf.system
            local dir = upload_path..system_path..'/'..os.date('%Y')..'/'..os.date('%m')..'/'..os.date('%d')..'/'
            local status = os.execute('mkdir -p '..dir)
            if status ~= 0 and status ~= true then
                ngx.say(dkjson.encode({code=10004, msg='创建目录失败'}))
                return
            end
            if extension then
                file_name = dir..file_id.."."..extension
            else
                file_name = dir..file_id
            end
            if file_name then
                file = io.open(file_name, "w+")
                if not file then
                    ngx.say(dkjson.encode({code=10003, msg='打开文件出错'}))
                    return
                end
            end
        end

    elseif typ == "body" then
        ngx.log(ngx.DEBUG , 'file size : ' , tonumber(res))
        if type(tonumber(res)) == 'number' and tonumber(res) > conf.max_size then
            ngx.say(dkjson.encode({code=10002, msg='文件超过规定大小', data=res}))
            return
        end
        if file then
            file:write(res)
        end
    elseif typ == "part_end" then
        if file then
            file:close()
            file = nil
        end
    elseif typ == "eof" then
        file_name = string.gsub(file_name, upload_path, '')
        local request_host =ngx.var.host
        if conf.scope == 'private' then
            url = private_host..file_name
        else
            file_name = string.gsub(file_name , '/public' , '')
            url =    public_host..file_name
        end
        ngx.say(dkjson.encode({code=10000, msg='上传成功！',url= url}))
        break
    else
        break
    end
end
