function Get-ServiceConfigurationData
{
    [cmdletbinding()]
    param ($Path)
    if (($script:ConfigurationData.Services.Keys.Count -eq 0))
    { 
        Write-Verbose "Processing Services from $Path." 
        foreach ( $item in (dir (join-path $Path 'Services\*.psd1')) )
        {
            Write-Verbose "Loading data for site $($item.basename) from $($item.fullname)."
            $script:ConfigurationData.Services.Add($item.BaseName, (Get-Hashtable $item.FullName))
        }
    }
}
