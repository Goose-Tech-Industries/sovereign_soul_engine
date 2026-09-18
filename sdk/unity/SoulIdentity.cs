using System;
using System.Numerics;
using System.Security.Cryptography;
using System.Text;

namespace SovereignSoul
{
    /// <summary>
    /// Self-contained Ed25519 (RFC 8032) using System.Numerics.BigInteger.
    /// No external dependencies. Slower than the optimized reference (ref10)
    /// but correct and perfectly adequate for identity setup and envelope
    /// signing in a game runtime (a few ms per operation).
    /// </summary>
    public static class Ed25519
    {
        // Field prime p = 2^255 - 19.
        static readonly BigInteger P = (BigInteger.One << 255) - 19;

        // Group order L.
        static readonly BigInteger L =
            (BigInteger.One << 252) +
            BigInteger.Parse("27742317777372353535851937790883648493");

        // Twisted Edwards curve constant d = -121665/121666 (mod p).
        // Computed from first principles to avoid any byte-order ambiguity.
        static readonly BigInteger D = Mod(-121665 * ModInverse(121666, P), P);

        // sqrt(-1) mod p = 2^((p-1)/4).
        static readonly BigInteger I = ModPow(2, (P - 1) / 4, P);

        // Base point (RFC 8032 §5.1), canonical encoding.
        static readonly byte[] BasePointEnc =
            HexToBytes("5866666666666666666666666666666666666666666666666666666666666666");

        struct Point { public BigInteger X, Y, Z; }

        static BigInteger Mod(BigInteger a, BigInteger m)
        {
            BigInteger r = a % m;
            return r < 0 ? r + m : r;
        }

        static BigInteger ModInverse(BigInteger a, BigInteger m)
        {
            // Extended Euclidean algorithm.
            BigInteger t = 0, newT = 1, r = m, newR = Mod(a, m);
            while (newR != 0)
            {
                BigInteger q = r / newR;
                (t, newT) = (newT, t - q * newT);
                (r, newR) = (newR, r - q * newR);
            }
            if (r != 1) throw new ArithmeticException("not invertible");
            return Mod(t, m);
        }

        static Point Add(Point p1, Point p2)
        {
            BigInteger a = Mod(p1.Z * p2.Z, P);
            BigInteger b = Mod(a * a, P);
            BigInteger c = Mod(p1.X * p2.X, P);
            BigInteger d = Mod(p1.Y * p2.Y, P);
            BigInteger e = Mod(D * c * d, P);
            BigInteger f = Mod(b - e, P);
            BigInteger g = Mod(b + e, P);
            BigInteger x3 = Mod(a * f * Mod(Mod(p1.X + p1.Y, P) * Mod(p2.X + p2.Y, P) - c - d, P), P);
            BigInteger y3 = Mod(a * g * Mod(d + c, P), P);   // d - a*c with a=-1
            BigInteger z3 = Mod(f * g, P);
            return new Point { X = x3, Y = y3, Z = z3 };
        }

        static Point Double(Point p1)
        {
            BigInteger bb = Mod(Mod(p1.X + p1.Y, P) * Mod(p1.X + p1.Y, P), P);
            BigInteger c = Mod(p1.X * p1.X, P);
            BigInteger d = Mod(p1.Y * p1.Y, P);
            BigInteger e = Mod(-c, P);                 // a = -1
            BigInteger f = Mod(e + d, P);
            BigInteger h = Mod(p1.Z * p1.Z, P);
            BigInteger j = Mod(f - 2 * h, P);
            BigInteger x3 = Mod(Mod(bb - c - d, P) * j, P);
            BigInteger y3 = Mod(f * Mod(e - d, P), P);
            BigInteger z3 = Mod(f * j, P);
            return new Point { X = x3, Y = y3, Z = z3 };
        }

        static Point ScalarMult(BigInteger k, Point p)
        {
            Point result = new Point { X = 0, Y = 1, Z = 1 }; // identity
            Point addend = p;
            while (k > 0)
            {
                if ((k & 1) == 1) result = Add(result, addend);
                addend = Double(addend);
                k >>= 1;
            }
            return result;
        }

        static BigInteger PointY(Point p) => Mod(p.Y * ModInverse(p.Z, P), P);
        static BigInteger PointX(Point p) => Mod(p.X * ModInverse(p.Z, P), P);

        static Point BasePoint() => DecodePoint(BasePointEnc);

        static byte[] EncodePoint(Point p)
        {
            BigInteger y = PointY(p);
            BigInteger x = PointX(p);
            byte[] enc = ToLittleEndian(y, 32);
            if ((x & 1) == 1) enc[31] |= 0x80;
            return enc;
        }

        static Point DecodePoint(byte[] enc)
        {
            bool sign = (enc[31] & 0x80) != 0;
            byte[] yBytes = (byte[])enc.Clone();
            yBytes[31] &= 0x7f;
            BigInteger y = FromLittleEndian(yBytes);
            if (y >= P) throw new ArgumentException("point out of range");

            // x^2 = (y^2 - 1) / (d*y^2 + 1)
            BigInteger y2 = Mod(y * y, P);
            BigInteger num = Mod(y2 - 1, P);
            BigInteger den = Mod(D * y2 + 1, P);
            BigInteger x2 = Mod(num * ModInverse(den, P), P);
            BigInteger x = ModPow(x2, (P + 3) / 8, P);
            if (Mod(x * x, P) != x2) x = Mod(x * I, P);
            if (Mod(x * x, P) != x2) throw new ArgumentException("not on curve");
            if ((x & 1) == 1 != sign) x = Mod(-x, P);

            return new Point { X = x, Y = y, Z = 1 };
        }

        static BigInteger ModPow(BigInteger b, BigInteger e, BigInteger m)
        {
            return BigInteger.ModPow(b, e, m);
        }

        static BigInteger Sha512ModL(byte[] data)
        {
            using var sha = SHA512.Create();
            byte[] digest = sha.ComputeHash(data);
            return Mod(FromLittleEndian(digest), L);
        }

        static byte[] ClampScalar(byte[] seed)
        {
            byte[] a = (byte[])seed.Clone();
            a[0] &= 248;
            a[31] &= 127;
            a[31] |= 64;
            return a;
        }

        /// <summary>Generates a fresh keypair. Returns (privateKey[32], publicKey[32]).</summary>
        public static (byte[] privateKey, byte[] publicKey) GenerateKeyPair()
        {
            byte[] seed = new byte[32];
            using (var rng = RandomNumberGenerator.Create()) rng.GetBytes(seed);
            byte[] pub = PublicKeyFromSeed(seed);
            return (seed, pub);
        }

        /// <summary>Derives the 32-byte public key from a 32-byte seed/private key.</summary>
        public static byte[] PublicKeyFromSeed(byte[] seed)
        {
            if (seed.Length != 32) throw new ArgumentException("seed must be 32 bytes");
            byte[] h = SHA512.HashData(seed);
            byte[] a = ClampScalar(h);
            BigInteger scalar = FromLittleEndian(a);
            return EncodePoint(ScalarMult(scalar, BasePoint()));
        }

        /// <summary>Signs a message with a 32-byte private key (RFC 8032). Returns 64-byte signature.</summary>
        public static byte[] Sign(byte[] message, byte[] privateKey)
        {
            if (privateKey.Length != 32) throw new ArgumentException("private key must be 32 bytes");

            byte[] h = SHA512.HashData(privateKey);
            byte[] a = ClampScalar(h);
            BigInteger scalar = FromLittleEndian(a);
            byte[] pub = EncodePoint(ScalarMult(scalar, BasePoint()));

            // r = SHA512(h[32..] || message) mod L
            byte[] prefix = new byte[32];
            Array.Copy(h, 32, prefix, 0, 32);
            byte[] rInput = new byte[prefix.Length + message.Length];
            Buffer.BlockCopy(prefix, 0, rInput, 0, prefix.Length);
            Buffer.BlockCopy(message, 0, rInput, prefix.Length, message.Length);
            BigInteger r = Sha512ModL(rInput);

            byte[] Renc = EncodePoint(ScalarMult(r, BasePoint()));

            // k = SHA512(R || pub || message) mod L
            byte[] kInput = new byte[Renc.Length + pub.Length + message.Length];
            Buffer.BlockCopy(Renc, 0, kInput, 0, Renc.Length);
            Buffer.BlockCopy(pub, 0, kInput, Renc.Length, pub.Length);
            Buffer.BlockCopy(message, 0, kInput, Renc.Length + pub.Length, message.Length);
            BigInteger k = Sha512ModL(kInput);

            BigInteger S = Mod(r + k * scalar, L);

            byte[] sig = new byte[64];
            Buffer.BlockCopy(Renc, 0, sig, 0, 32);
            byte[] sBytes = ToLittleEndian(S, 32);
            Buffer.BlockCopy(sBytes, 0, sig, 32, 32);
            return sig;
        }

        /// <summary>Verifies a 64-byte signature against a 32-byte public key (RFC 8032).</summary>
        public static bool Verify(byte[] message, byte[] signature, byte[] publicKey)
        {
            if (signature.Length != 64 || publicKey.Length != 32) return false;

            byte[] Renc = new byte[32];
            Buffer.BlockCopy(signature, 0, Renc, 0, 32);
            byte[] sBytes = new byte[32];
            Buffer.BlockCopy(signature, 32, sBytes, 0, 32);
            BigInteger S = FromLittleEndian(sBytes);
            if (S >= L) return false;

            Point A, R;
            try { A = DecodePoint(publicKey); R = DecodePoint(Renc); }
            catch { return false; }

            byte[] kInput = new byte[Renc.Length + publicKey.Length + message.Length];
            Buffer.BlockCopy(Renc, 0, kInput, 0, Renc.Length);
            Buffer.BlockCopy(publicKey, 0, kInput, Renc.Length, publicKey.Length);
            Buffer.BlockCopy(message, 0, kInput, Renc.Length + publicKey.Length, message.Length);
            BigInteger k = Sha512ModL(kInput);

            Point SB = ScalarMult(S, BasePoint());
            Point RkA = Add(R, ScalarMult(k, A));
            return EncodePoint(SB).AsSpan().SequenceEqual(EncodePoint(RkA));
        }

        // ── byte helpers ────────────────────────────────────────────────────

        static BigInteger FromLittleEndian(byte[] bytes)
        {
            byte[] rev = (byte[])bytes.Clone();
            Array.Reverse(rev);
            return new BigInteger(rev, isUnsigned: true, isBigEndian: true);
        }

        static byte[] ToLittleEndian(BigInteger value, int length)
        {
            byte[] big = value.ToByteArray(isUnsigned: true, isBigEndian: true);
            byte[] outBytes = new byte[length];
            int copy = Math.Min(big.Length, length);
            // big is big-endian; write the least significant `copy` bytes reversed.
            for (int i = 0; i < copy; i++)
                outBytes[i] = big[big.Length - 1 - i];
            return outBytes;
        }

        static byte[] HexToBytes(string hex)
        {
            byte[] bytes = new byte[hex.Length / 2];
            for (int i = 0; i < bytes.Length; i++)
                bytes[i] = Convert.ToByte(hex.Substring(i * 2, 2), 16);
            return bytes;
        }

        /// <summary>
        /// Self-test against RFC 8032 test vector #1. Returns true if the
        /// implementation signs/verifies correctly. Call once at startup in
        /// editor/development to validate the port on your platform.
        /// </summary>
        public static bool SelfTest()
        {
            byte[] seed = HexToBytes("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60");
            byte[] pub = HexToBytes("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a");
            byte[] sig = HexToBytes("e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b");
            byte[] msg = new byte[0];

            byte[] derived = PublicKeyFromSeed(seed);
            if (!derived.AsSpan().SequenceEqual(pub)) return false;

            byte[] produced = Sign(msg, seed);
            if (!produced.AsSpan().SequenceEqual(sig)) return false;

            return Verify(msg, sig, pub);
        }
    }
}
