#requires -Version 1 -Modules PKI

<#
$GBCI_Certs = Get-Certificate -StoreName Root -CertStoreLocation .\\LocalMachine -Thumbprint * | Where-Object -FilterScript {
    $PSItem.Subject -ilike '*glacierbancorp*'
}
#>

<#
    Alternative to PKI module requirement?
    Get-ChildItem -Path Cert:\LocalMachine -Recurse | where { $_.notafter -le (get-date).AddDays(90) -AND $_.notafter -gt (get-date)} | FL -Property thumbprint,subject,notbefore,notafter
#>

$GBCI_Certs = Get-ChildItem -Path Cert:\ -Recurse -Exclude "*Disallowed*" -ExpiringInDays 360 | Where-Object -FilterScript {$PSItem.PSPath -notlike "*Disallowed*"} | Select-Object -Property PSPath,Subject,Issuer,Version,DnsNameList,NotAfter -ExpandProperty SignatureAlgorithm

ForEach-Object -InputObject $GBCI_Certs -Process {
    Write-Output -InputObject "Testing GBCI Cert(s): $($PSItem.DnsNameList) ..."
    Test-Certificate -Cert $PSItem
    $PSItem | Select-Object -Property *
}

<#
        Certificate object (System.Security.Cryptography.X509Certificates.X509Certificate2) Methods:
        Name                            MemberType     Definition                                                                                         
        ----                            ----------     ----------                                                                                         
        Dispose                         Method         void Dispose(), void IDisposable.Dispose()                                                         
        Equals                          Method         bool Equals(System.Object obj), bool Equals(System.Security.Cryptography.X509Certificates.X509Ce...
        Export                          Method         byte[] Export(System.Security.Cryptography.X509Certificates.X509ContentType contentType), byte[]...
        GetCertHash                     Method         byte[] GetCertHash()                                                                               
        GetCertHashString               Method         string GetCertHashString()                                                                         
        GetEffectiveDateString          Method         string GetEffectiveDateString()                                                                    
        GetExpirationDateString         Method         string GetExpirationDateString()                                                                   
        GetFormat                       Method         string GetFormat()                                                                                 
        GetHashCode                     Method         int GetHashCode()                                                                                  
        GetIssuerName                   Method         string GetIssuerName()                                                                             
        GetKeyAlgorithm                 Method         string GetKeyAlgorithm()                                                                           
        GetKeyAlgorithmParameters       Method         byte[] GetKeyAlgorithmParameters()                                                                 
        GetKeyAlgorithmParametersString Method         string GetKeyAlgorithmParametersString()                                                           
        GetName                         Method         string GetName()                                                                                   
        GetNameInfo                     Method         string GetNameInfo(System.Security.Cryptography.X509Certificates.X509NameType nameType, bool for...
        GetObjectData                   Method         void ISerializable.GetObjectData(System.Runtime.Serialization.SerializationInfo info, System.Run...
        GetPublicKey                    Method         byte[] GetPublicKey()                                                                              
        GetPublicKeyString              Method         string GetPublicKeyString()                                                                        
        GetRawCertData                  Method         byte[] GetRawCertData()                                                                            
        GetRawCertDataString            Method         string GetRawCertDataString()                                                                      
        GetSerialNumber                 Method         byte[] GetSerialNumber()                                                                           
        GetSerialNumberString           Method         string GetSerialNumberString()                                                                     
        GetType                         Method         type GetType()                                                                                     
        Import                          Method         void Import(byte[] rawData), void Import(byte[] rawData, string password, System.Security.Crypto...
        OnDeserialization               Method         void IDeserializationCallback.OnDeserialization(System.Object sender)                              
        Reset                           Method         void Reset()                                                                                       
        ToString                        Method         string ToString(), string ToString(bool verbose)                                                   
        Verify                          Method         bool Verify()                                                                                      
#>
