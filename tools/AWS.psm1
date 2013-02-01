# TODO: add the ability to additionally grab addresses given a tag -- this can
# be used during continuous builds to identify the server on which to run tests


# well, I changed a couple things
# Don McNamara
# Jan-24 3:08 PM
# not sure if they are all needed
# Don McNamara
# Jan-24 3:09 PM
# "&Expires=$expires&Filter.1.Name=tag%3AName&Filter.1.Value.1=$Name&" +
# Don McNamara
# Jan-24 3:09 PM
# forgot to escape the : in the tag:Name part
# Don McNamara
# Jan-24 3:09 PM
# $urlEncoded = (UrlEncode $base64Encoded)
# Don McNamara
# Jan-24 3:09 PM
# removed the .ToUpper() call
# Ethan Brown
# Jan-24 3:09 PM
# yeah... i only used ToUpper because all the examples had upper case hex chars
# Ethan Brown
# Jan-24 3:09 PM
# that was me grasping at straws ;0
# Don McNamara
# Jan-24 3:09 PM
# not sure if it matters or not, but I also changed the version
# Don McNamara
# Jan-24 3:09 PM
# "SignatureMethod=HmacSHA256&SignatureVersion=2&Version=2012-12-01")
# Ethan Brown
# Jan-24 3:10 PM
# and I think that was *before* I removed the HttpUtility.UrlEncode and swapped in the AWS style one
# Don McNamara
# Jan-24 3:10 PM
# I think it was the ToUpper that was causing problems
# Don McNamara
# Jan-24 3:10 PM
# at least with the signature
# Don McNamara
# Jan-24 3:10 PM
# oh, and the date format thing


#Requires -Version 3.0

$script:validUrlCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~"
$script:iso8601DateFormat = "yyyy-MM-dd\\THH:mm:ss.fff\\Z"

# http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-query-api.html
# https://github.com/aws/aws-sdk-net/blob/master/AWSSDK/Amazon.Util/AWSSDKUtils.cs#L779
function UrlEncode([string]$data, [bool]$path)
{
  $encoded = New-Object Text.StringBuilder($data.Length * 2)
  $allowedChars = $script:validUrlCharacters
  if ($path) { $allowedChars += "/:" }

  [Text.Encoding]::UTF8.GetBytes($data) |
    % {
      $char = [char]$_
      if ($allowedChars.IndexOf($char) -ne -1) { [Void]$encoded.Append($char) }
      else { [Void]$encoded.Append('%').Append([string]::Format('{0:X2}', [int]$char)) }
    }

  return $encoded.ToString()
}

function Describe-EC2Instance
{
  param
  (
    [Parameter(Mandatory=$false)]
    [string]
    $Server = 'ec2.amazonaws.com', # 'ec2.us-east-1.amazonaws.com', # 'ec2.amazonaws.com',

    [Parameter(Mandatory=$true)]
    [string]
    $Name,

    [Parameter(Mandatory=$true)]
    [string]
    $AccessKey,

    [Parameter(Mandatory=$true)]
    [string]
    $SecretKey,

    [Parameter(Mandatory=$false)]
    [DateTime]
    $ExpireDate = [DateTime]::Now.AddMinutes(20)
  )

  # some code borrowed from AWS toolkit
  # https://github.com/aws/aws-sdk-net/blob/master/AWSSDK/Amazon.Util/AWSSDKUtils.cs

  $expires = UrlEncode(
    #$ExpireDate.ToUniversalTime().ToString('yyyy-MM-dd\\THH:mm:ss.fff\\Z')).ToUpper()
    $ExpireDate.ToUniversalTime().ToString($script:iso8601DateFormat)).ToUpper()
  #yyyy-MM-dd\\THH:mm:ss\\Z
     #.ToString('o')
  #.ToString ( "s", System.Globalization.CultureInfo.InvariantCulture
  #$awsBaseTime = [DateTime]::Parse("1970-01-01T00:00:00.0000000Z")
  #$expires = [Convert]::ToInt32($ExpireDate.Subtract($awsBaseTime).TotalSeconds).ToString()
  $httpRequestUri = '/'

  # AWS encodings and .NET don't really play nice
  # http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-query-api.html
  $Name = (UrlEncode $Name) -replace '%2f', '/'
  $Name = $Name -replace '\+', '%20'

  $queryString = ("AWSAccessKeyId=$AccessKey&Action=DescribeInstances" +
    "&Expires=$expires&Filter.1.Name=tag:Name&Filter.1.Value.1=$Name&" +
    "SignatureMethod=HmacSHA256&SignatureVersion=2&Version=2012-12-01")

  $stringToSign = "GET`n$($Server.ToLower())`n$httpRequestUri`n$queryString"

  $sha = New-Object Security.Cryptography.HMACSHA256
  $sha.Key = [Text.Encoding]::UTF8.Getbytes($SecretKey)
  $seedBytes = [Text.Encoding]::UTF8.GetBytes($stringToSign)
  $digest = $sha.ComputeHash($seedBytes)
  $base64Encoded = [Convert]::ToBase64String($digest)

  $urlEncoded = (UrlEncode $base64Encoded).ToUpper()# -replace '%2f', '/'

  $url = "https://$Server/?$queryString&Signature=$urlEncoded"
  Write-Host $url
  Invoke-RestMethod $url
}


