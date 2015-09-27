type BSONObject
    _wrap_::Ptr{Void}
    _owner_::Any

    BSONObject() = begin
        _wrap_ = ccall(
            (:bson_new, libbson),
            Ptr{Void}, ()
            )
        bsonObject = new(_wrap_, None)
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
        append(bsonObject, tup[1], tup[2])
        return bsonObject
    end

    BSONObject(jsonString::AbstractString) = begin
        jsonCStr = bytestring(jsonString)
        bsonError = BSONError()
        _wrap_ = ccall(
            (:bson_new_from_json, libbson),
            Ptr{Void}, (Ptr{Uint8}, Csize_t, Ptr{Uint8}),
            jsonCStr,
            length(jsonCStr),
            bsonError._wrap_
            )
        _wrap_ != C_NULL || error(bsonError)
        bsonObject = new(_wrap_, None)
        finalizer(bsonObject, destroy)
        return bsonObject
    end

    BSONObject(data::Ptr{Uint8}, length::Integer, _ref_::Any) = begin
        buffer = Array(Uint8, 128)
        ccall(
            (:bson_init_static, libbson),
            Bool, (Ptr{Void}, Ptr{Uint8}, Uint32),
            buffer, data, length
            ) || error("bson_init_static: failure")
        b = Compat.unsafe_convert(Ptr{Void}, buffer)
        new(b, (_ref_, b))
    end

    BSONObject(_wrap_::Ptr{Void}, _owner_::Any) = new(_wrap_, _owner_)
end
export BSONObject

function convert(::Type{AbstractString}, bsonObject::BSONObject)
    cstr = ccall(
        (:bson_as_json, libbson),
        Ptr{Uint8}, (Ptr{Void}, Ptr{Uint8}),
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
        Uint32, (Ptr{Void},),
        bsonObject._wrap_
        )
export length

function append(bsonObject::BSONObject, key::AbstractString, val::Bool)
    keyCStr = bytestring(key)
    ccall(
        (:bson_append_bool, libbson),
        Bool, (Ptr{Void}, Ptr{Uint8}, Cint, Bool),
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
        Bool, (Ptr{Void}, Ptr{Uint8}, Cint, Cdouble),
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
        Bool, (Ptr{Void}, Ptr{Uint8}, Cint, Ptr{Uint8}),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        val._wrap_
        ) || error("libBSON: overflow")
end
function append(bsonObject::BSONObject, key::AbstractString, val::Union(Int8, Uint8, Int16, Uint16, Int32, Uint32))
    keyCStr = bytestring(key)
    ccall(
        (:bson_append_int32, libbson),
        Bool, (Ptr{Void}, Ptr{Uint8}, Cint, Cint),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        val
        ) || error("libBSON: overflow")
end
function append(bsonObject::BSONObject, key::AbstractString, val::Union(Int64, Uint64))
    keyCStr = bytestring(key)
    ccall(
        (:bson_append_int64, libbson),
        Bool, (Ptr{Void}, Ptr{Uint8}, Cint, Clong),
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
        Bool, (Ptr{Void}, Ptr{Uint8}, Cint, Clong),
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
        Bool, (Ptr{Void}, Ptr{Uint8}, Cint, Ptr{Uint8}),
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
        Bool, (Ptr{Void}, Ptr{Uint8}, Cint, Ptr{Uint8}, Cint),
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
function append(bsonObject::BSONObject, key::AbstractString, val::Tuple{AbstractString, Any})
    d = Dict{AbstractString, Any}(val[1]=>val[2])
    append(bsonObject, key, d)
end
function append(bsonObject::BSONObject, key::AbstractString, val::Dict)
    keyCStr = bytestring(key)
    childBuffer = Array(Uint8, 128)
    ccall(
        (:bson_append_document_begin, libbson),
        Bool, (Ptr{Void}, Ptr{Uint8}, Cint, Ptr{Void}),
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
    childBuffer = Array(Uint8, 128)
    ccall(
        (:bson_append_array_begin, libbson),
        Bool, (Ptr{Void}, Ptr{Uint8}, Cint, Ptr{Void}),
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
        Bool, (Ptr{Void}, Ptr{Uint8}, Cint),
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
        Bool, (Ptr{Void}, Ptr{Uint8}, Cint),
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
        Bool, (Ptr{Void}, Ptr{Uint8}, Cint),
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
