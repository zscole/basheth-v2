        while (material.length < clen.key + clen.iv) {
                bufs = [];
                if (D_prev)
                        bufs.push(D_prev);
                bufs.push(passphrase);
                bufs.push(salt);
                D = Buffer.concat(bufs);
                for (var j = 0; j < count; ++j)
                        D = crypto.createHash('md5').update(D).digest();
                material = Buffer.concat([material, D]);
                D_prev = D;
        }

        return ({
            key: material.slice(0, clen.key),
            iv: material.slice(clen.key, clen.key + clen.iv)
        });
}

/* Count leading zero bits on a buffer */
function countZeros(buf) {
        var o = 0, obit = 8;
        while (o < buf.length) {
                var mask = (1 << obit);
                if ((buf[o] & mask) === mask)
                        break;
                obit--;
                if (obit < 0) {
                        o++;
                        obit = 8;
                }
        }
        return (o*8 + (8 - obit) - 1);
}

function bufferSplit(buf, chr) {
        assert.buffer(buf);
        assert.string(chr);

        var parts = [];
        var lastPart = 0;
        var matches = 0;