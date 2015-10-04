type BSONObject
    _wrap_::Ptr{Void}
    _owner_::Any

    BSONObject() = begin
        _wrap_ = ccall(
            (:bson_new, libbson),
            Ptr{Void}, ()
            )
        bsonObject = new(_wrap_, Union{})
        finalizer(bsonObject, destroy)
        return bsonObject
    end

    BSONObject(dict::Associative) = begin
        bsonObject = BSONObject()
        for (k, v) in dict
            append(bsonObject, k, v)
        end
        return bsonObject
    end

    BSONObject{T <: Tuple{AbstractString, Any}}(arr::Array{T, 1}) = begin
        bsonObject = BSONObject()
        for (k, v) in arr
            append(bsonObject, k, v)
        end
        return bsonObject
    end

    BSONObject(tup::Tuple{AbstractString, Any}) = begin
        bsonObject = BSONObject()
        key = tup[1]
        val = tup[2]
        append(bsonObject, key, val)
        return bsonObject
    end

    BSONObject(jsonString::AbstractString) = begin
        jsonCStr = bytestring(jsonString)
        bsonError = BSONError()
        _wrap_ = ccall(
            (:bson_new_from_json, libbson),
            Ptr{Void}, (Ptr{UInt8}, Csize_t, Ptr{UInt8}),
            jsonCStr,
            length(jsonCStr),
            bsonError._wrap_
            )
        _wrap_ != C_NULL || error(bsonError)
        bsonObject = new(_wrap_, Union{})
        finalizer(bsonObject, destroy)
        return bsonObject
    end

    BSONObject(data::Ptr{UInt8}, length::Integer, _ref_::Any) = begin
        buffer = Array(UInt8, 128)
        ccall(
            (:bson_init_static, libbson),
            Bool, (Ptr{Void}, Ptr{UInt8}, UInt32),
            buffer, data, length
            ) || error("bson_init_static: failure")
        b = Compat.unsafe_convert(Ptr{Void}, buffer)
        new(b, (_ref_, b))
    end

    BSONObject(_wrap_::Ptr{Void}, _owner_::Any) = begin
        bsonObject = BSONObject()
        ccall(
            (:bson_copy_to, libbson),
            Void, (Ptr{Void}, Ptr{Void}),
            _wrap_, bsonObject._wrap_
        )
        return bsonObject
    end
end
export BSONObject

function convert(::Type{AbstractString}, bsonObject::BSONObject)
    cstr = ccall(
        (:bson_as_json, libbson),
        Ptr{UInt8}, (Ptr{Void}, Ptr{UInt8}),
        bsonObject._wrap_,
        C_NULL
        )
    result = bytestring(cstr)
    ccall(
        (:bson_free, libbson),
        Void, (Ptr{Void},),
        cstr
        )
    return result
end
export convert

string(bsonObject::BSONObject) = convert(AbstractString, bsonObject)

show(io::IO, bsonObject::BSONObject) = print(io, "BSONObject($(convert(AbstractString, bsonObject)))")
export show

length(bsonObject::BSONObject) =
    ccall(
        (:bson_count_keys, libbson),
        UInt32, (Ptr{Void},),
        bsonObject._wrap_
        )
export length

function append(bsonObject::BSONObject, key::AbstractString, val::Bool)
    keyCStr = bytestring(key)
    ccall(
        (:bson_append_bool, libbson),
        Bool, (Ptr{Void}, Ptr{UInt8}, Cint, Bool),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        val
        ) || error("libBSON: overflow")
end
function append(bsonObject::BSONObject, key::AbstractString, val::Real)
    keyCStr = bytestring(key)
    ccall(
        (:bson_append_double, libbson),
        Bool, (Ptr{Void}, Ptr{UInt8}, Cint, Cdouble),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        val
        ) || error("libBSON: overflow")
end
function append(bsonObject::BSONObject, key::AbstractString, val::BSONObject)
    keyCStr = bytestring(key)
    ccall(
        (:bson_append_document, libbson),
        Bool, (Ptr{Void}, Ptr{UInt8}, Cint, Ptr{UInt8}),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        val._wrap_
        ) || error("libBSON: overflow")
end
function append(bsonObject::BSONObject, key::AbstractString, val::Union{Int8, UInt8, Int16, UInt16, Int32, UInt32})
    keyCStr = bytestring(key)
    ccall(
        (:bson_append_int32, libbson),
        Bool, (Ptr{Void}, Ptr{UInt8}, Cint, Cint),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        val
        ) || error("libBSON: overflow")
end
function append(bsonObject::BSONObject, key::AbstractString, val::Union{Int64, UInt64})
    keyCStr = bytestring(key)
    ccall(
        (:bson_append_int64, libbson),
        Bool, (Ptr{Void}, Ptr{UInt8}, Cint, Clong),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        val
        ) || error("libBSON: overflow")
end

function append(bsonObject::BSONObject, key::AbstractString, val::Date)
    append(bsonObject, key, DateTime(val))
end

function append(bsonObject::BSONObject, key::AbstractString, val::DateTime)
    keyCStr = bytestring(key)
    val_utc_js = Dates.datetime2unix(val)*1000 |> Int64
    ccall(
        (:bson_append_date_time, libbson),
        Bool, (Ptr{Void}, Ptr{UInt8}, Cint, Clong),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        val_utc_js
        ) || error("libBSON: overflow")
end
function append(bsonObject::BSONObject, key::AbstractString, val::BSONOID)
    keyCStr = bytestring(key)
    ccall(
        (:bson_append_oid, libbson),
        Bool, (Ptr{Void}, Ptr{UInt8}, Cint, Ptr{UInt8}),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        val._wrap_
        ) || error("libBSON: overflow")
end
function append(bsonObject::BSONObject, key::AbstractString, val::AbstractString)
    keyCStr = bytestring(key)
    valUTF8 = utf8(val)
    ccall(
        (:bson_append_utf8, libbson),
        Bool, (Ptr{Void}, Ptr{UInt8}, Cint, Ptr{UInt8}, Cint),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        valUTF8,
        sizeof(valUTF8)
        ) || error("libBSON: overflow")
end
function append(bsonObject::BSONObject, key::AbstractString, val::Type)
    append_null(bsonObject, key)
end
function append(bsonObject::BSONObject, key::AbstractString, val::Nothing)
    append_null(bsonObject, key)
end
function append(bsonObject::BSONObject, key::AbstractString, val::Symbol)
    if val == :null
        append_null(bsonObject, key)
    elseif val == :minkey
        append_minkey(bsonObject, key)
    elseif val == :maxkey
        append_maxkey(bsonObject, key)
    else
        append(bsonObject, key, string(val))
    end
end
function append{T <: Tuple{AbstractString, Any}}(bsonObject::BSONObject, key::AbstractString, arr::Array{T, 1})
    bsonObjectVal = BSONObject(val)
    append(bsonObject, key, bsonObjectVal)
end
function append(bsonObject::BSONObject, key::AbstractString, val::Tuple{Any, Any})
    append(bsonObject, key, val)
end
function append(bsonObject::BSONObject, key::Tuple{AbstractString, Any}, val::Tuple{AbstractString, Any})
    append(bsonObject, key, val)
end
function append(bsonObject::BSONObject, key::AbstractString, val::Dict)
    keyCStr = bytestring(key)
    childBuffer = Array(UInt8, 128)
    ccall(
        (:bson_append_document_begin, libbson),
        Bool, (Ptr{Void}, Ptr{UInt8}, Cint, Ptr{Void}),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        childBuffer
        ) || error("bson_append_document_begin: failure")
    childBSON = BSONObject(Compat.unsafe_convert(Ptr{Void}, childBuffer), childBuffer)
    for (k, v) in val
        append(childBSON, k, v)
    end
    ccall(
        (:bson_append_document_end, libbson),
        Bool, (Ptr{Void}, Ptr{Void}),
        bsonObject._wrap_,
        childBuffer
        ) || error("bson_append_document_end: failure")
end
function append(bsonObject::BSONObject, key::AbstractString, val::Vector)
    keyCStr = bytestring(key)
    childBuffer = Array(UInt8, 128)
    ccall(
        (:bson_append_array_begin, libbson),
        Bool, (Ptr{Void}, Ptr{UInt8}, Cint, Ptr{Void}),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        childBuffer
        ) || error("bson_append_array_begin: failure")
    childBSONArray = BSONArray(Compat.unsafe_convert(Ptr{Void}, childBuffer), childBuffer)
    for element in val
        append(childBSONArray, element)
    end
    ccall(
        (:bson_append_array_end, libbson),
        Bool, (Ptr{Void}, Ptr{Void}),
        bsonObject._wrap_,
        childBuffer
        ) || error("bson_append_array_end: failure")
end
export append

function append_null(bsonObject::BSONObject, key::AbstractString)
    keyCStr = bytestring(key)
    ccall(
        (:bson_append_null, libbson),
        Bool, (Ptr{Void}, Ptr{UInt8}, Cint),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr)
        ) || error("libBSON: overflow")
end
export append_null

function append_minkey(bsonObject::BSONObject, key::AbstractString)
    keyCStr = bytestring(key)
    ccall(
        (:bson_append_minkey, libbson),
        Bool, (Ptr{Void}, Ptr{UInt8}, Cint),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr)
        ) || error("libBSON: overflow")
end
export append_minkey

function append_maxkey(bsonObject::BSONObject, key::AbstractString)
    keyCStr = bytestring(key)
    ccall(
        (:bson_append_maxkey, libbson),
        Bool, (Ptr{Void}, Ptr{UInt8}, Cint),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr)
        ) || error("libBSON: overflow")
end
export append_maxkey

dict(bsonObject::BSONObject) = begin
    d = Dict{Any, Any}()
    for (k, v) in bsonObject
        if isa(v, BSONObject)
            d[k] = dict(v)
        elseif isa(v, BSONArray)
            d[k] = vector(v)
        else
            d[k] = v
        end
    end
    return d
end
export dict

# Private

function destroy(bsonObject::BSONObject)
    ccall(
        (:bson_destroy, libbson),
        Void, (Ptr{Void},),
        bsonObject._wrap_
        )
end
