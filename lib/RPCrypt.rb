
require 'openssl'
require 'base64'

class RPCrypt
	# Create a new crypt object, initializing it with public and private keys
	def initialize ( public_file, private_file )
	    @public_key = OpenSSL::PKey::RSA.new(public_file)
	    @private_key_file = private_file
	    @private_key = nil
	end

	def encrypt(string)
	    Base64.encode64(@public_key.public_encrypt(string))
	end

	def decrypt(encrypted_string, password)
	    if(@private_key.nil?)
		password = 's;$VQU@A\{5@pXO:uDDh' if password.empty?
		@private_key = OpenSSL::PKey::RSA.new(@private_key_file,
						      password)
	    end
	    @private_key.private_decrypt(Base64.decode64(encrypted_string))
	end
end

rpc = RPCrypt.new("-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAq2ChaigVUIvZlyUeXDAe\n2X2J8jM/fp5mFvLeOVAhkrWSnTK/TRLAN3T3TIpS6iTKIKgRP5ZsSn/FTtCh/CCz\nK27h6iBQZgeIgbhcInMVEQgn2u7O8Y1bvunwANUlP/EtmIWuqbeEo/bPzWbFro2u\nKrUQDzQfcQgFKEeiqGVNuY6LfzQzGeiEEVZuXpRmGUfQJ8i4/cfa5IF5wK3RfB74\nEvUHw4mwFEdlCEvwW3xs2neSodHlFZ7RA/N3sS7OAIs6kL3c7hNME8NQIPpuGirY\nBDL2Qa8vVc7Q8c5fEltOFy30gWOtpYKtav5EdCTBpdre+PuN2bCASlXSQuIefEf7\nSQIDAQAB\n-----END PUBLIC KEY-----\n",
"-----BEGIN RSA PRIVATE KEY-----\nProc-Type: 4,ENCRYPTED\nDEK-Info: DES-EDE3-CBC,327F1FC43C2C8ADF\n\nRBNuoBVbst0T6ACHTWoXv+WutmPKANlPErY7G4CkhSU0E/9pquEGJA9ecaQs7XbB\n1OkVPdTrLVuORXUfrURcsktNtVVyOujdBvZJFqmn7SG3u+Z61AIxeHfQI3efYP09\nynxfuQKYBkg9pEGWsQTqsLf+0epsLVF88f5PYGXoZzER5CsAlfAeQVV28PE6jL1+\nCIgzcM4vapV73hZ4CqBlO16VDqPIQSn1NH+mRESbiVnE4o+eAVsPQWcwCugYLXti\nUfzEFZ+YuCCYryWqOpc1j+GjYWOHacB5hPcyPWB4phcy6udZkKWBZEF2KDPIpMsd\nn3mDBgQCDxiW/HLDB5K+McaNQe3IzkXHeU8FnQth61GSCSWmBookuObJ7nA18j1r\nn1eRg48+Dkq6VrWtsECmcVQiK7k3RhkDCkaq958gZl5TedwcrI/fIvsZzuDXiUxM\nSryr8pQITX+cEuqBTanswRYY1nsFGgz/il1lZOhm/8quOP2V9UgxiWh3s83ME//Q\nS+VggLx71BFr4uXXde4FRpgEFVkynt9pswc/Uf4uHDSldqiaXv8G35l57gW4/YWO\nB/6zojNFVAOqJzCHAbaPs1k7NtlOb3+ORNyWRqCXEGUpurt41S3+ZeHlDXr5D25S\nkl//nzkqPdd5pct5VP6JO/P1MaSjxyU6uN9f1LvOvhpGvGU8Bc11tcfGiVenGfgJ\nmlC16xL4ydWpTBIWWvSGGftcQaa34IP7IKgAnQnOugplbxfyAioDFLpomqxlxWZy\nxvL7yaooUi2617zwF9SiuaM6Z6Ak21jy+/mPdaQhsbtm2Vb5VDzcB5rG3TB5kgNf\nB0dkNi45YVjFzTSB16pj0y2X88244hn8ZPDFr9svcylPzYmRW1+0hrRv1hHmkfAM\nzlhFG1KGYRFMo9LA95tjPKH6BCn6QHEBVRg0fxz/5e3QOc4Eew+EUE6GcZzBbEs3\nsZrsDvsv6c9XARrF6w5Gr0UXYpBP3ok6LpITHoMhbAuFkrpicBXNuNZKdxcjn/W7\n3URpwdTzLDOgC5kEHcBtmLHCew334jjXHg372wmaW6fIOmkABsFmg8UuFUF4ABZn\nTfxrpdbfHsVH2AUkCAoVqW6XY4jwmGxwgUUOotvNLTyemyt5eu/lUDyLgzvf3fX0\n8QzPQqBu6j50M0gODA0YG0L+yjybJxiXpJwg1mSGP1clbXFCT6bFP91rWVjuGhLv\nKm5yia9YJPvP100Xz5P37qK7LwPmqnTfAbEtEEAbLj5JVdaazd74tQP17P493iS1\nTSpHsPG4/aQNw3sWl8jRShfiThJkd5nj6kQBgcYnPg6h5NAS6OEHagEauetUjXA3\niiOuBtdSv15DG/k8guzuhmTr97kLT6KN7hfgU0j30NT/ebwelbI7CziqEvl3yixr\nfBu40WGgA+181XQCOIg65M1nXbbIRGz0N2/TDNz2SAG/lv35YaTH9xsfVjALxxJx\nfRVmMv4yJHbXO4ux7BOi951A3J5wg7vHyBpCMnSlqoifXbEDyjwZQbVCDxiZRwyZ\nD3Lv4Za1U1gtbUEVGwjZtBBUPq6z5zU1x9FIEc2+eb81CQ5UiR0h1S42ID35/85+\n-----END RSA PRIVATE KEY-----\n")

encr = rpc.encrypt "Hello World!"

puts rpc.decrypt encr, ""
