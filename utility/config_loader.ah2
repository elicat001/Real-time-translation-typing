#Requires AutoHotkey v2.0

AppConfig_Load(json_path)
{
    try
    {
        raw := FileRead(json_path, 'UTF-8')
    }
    catch as e
    {
        throw Error("无法读取配置文件 '" json_path "': " e.Message)
    }

    try
    {
        config := JSON.parse(raw)
    }
    catch as e
    {
        throw Error("配置文件解析失败: " e.Message)
    }

    if (Type(config) != 'Map')
        throw Error('配置文件的顶级结构必须是对象（Map）')

    if !config.Has('all_api')
        config['all_api'] := []
    else if (Type(config['all_api']) != 'Array')
        throw Error('all_api 必须为数组')

    ; 为所有在列表中的服务确保存在元数据映射，避免访问缺失键时报错。
    for _, name in config['all_api']
    {
        if !config.Has(name)
            config[name] := Map()
    }

    return config
}

AppConfig_Save(config, json_path)
{
    str := JSON.stringify(config, 4)
    FileDelete(json_path)
    FileAppend(str, json_path, 'UTF-8')
}

AppConfig_GetServiceMeta(config, name)
{
    if !config.Has(name)
    {
        meta := Map()
        config[name] := meta
        return meta
    }

    meta := config[name]
    if (Type(meta) = 'Map')
        return meta

    normalized := Map()
    for key, value in meta
    {
        normalized[key] := value
    }
    config[name] := normalized
    return normalized
}

AppConfig_ServiceSupportsScope(meta, scope)
{
    if (scope = '')
        return true

    if !meta.Has('scopes')
        return true

    scopes := meta['scopes']
    if (Type(scopes) = 'Array')
    {
        for _, value in scopes
        {
            if (value = scope)
                return true
        }
        return false
    }

    return scopes = scope
}

AppConfig_ServiceIsOpen(meta)
{
    return !meta.Has('is_open') || meta['is_open']
}

AppConfig_GetEnabledServices(config, scope := '')
{
    services := []
    if !config.Has('all_api')
        return services

    for _, name in config['all_api']
    {
        meta := AppConfig_GetServiceMeta(config, name)
        if !AppConfig_ServiceSupportsScope(meta, scope)
            continue
        if !AppConfig_ServiceIsOpen(meta)
            continue
        services.Push(name)
    }
    return services
}

AppConfig_ResolveDefaultService(config, scope := '', fallback := '')
{
    defaultName := ''
    if (scope = 'web' && config.Has('web_cd'))
        defaultName := config['web_cd']
    else if (scope = 'api' && config.Has('cd'))
        defaultName := config['cd']
    else if config.Has('cd')
        defaultName := config['cd']

    if (defaultName = '')
        defaultName := fallback

    enabled := AppConfig_GetEnabledServices(config, scope)
    for _, name in enabled
    {
        if (name = defaultName)
            return name
    }

    if (enabled.Length)
        return enabled[1]

    return defaultName
}

AppConfig_GetMetaValue(meta, key, default := '')
{
    return meta.Has(key) ? meta[key] : default
}
