from os import path
from datetime import datetime

from Crypto.Cipher import AES
from Crypto.Util import Counter
from Crypto import Random

import base64
import hashlib
import string
import random
import binascii


class Cipher(object):

    cipher = None

    @classmethod
    def get(cls, type):
        if not cls.cipher:
            cls.cipher = AESCipher((
                '/etc/ssl/certs/zimagi.crt',
                '/usr/local/share/ca-certificates/zimagi-ca.crt'
            ))
        return cls.cipher


class AESCipher:

    @classmethod
    def generate_key(cls):
        chars = string.ascii_uppercase + string.digits
        return ''.join(random.SystemRandom().choice(chars) for _ in range(32))


    def __init__(self, keys = None):
        if not keys:
            keys = []

        self.binary_marker = '<<<<-->BINARY<-->>>>'
        self.batch_size = AES.block_size

        if keys:
            combined_key = ''
            for key in keys:
                if path.isfile(key):
                    with open(key, 'r') as file:
                        key = file.read()

                combined_key += key

            self.key = hashlib.sha256(combined_key.encode()).digest()
        else:
            self.key = self.__class__.generate_key()


    def encrypt(self, message):
        iv = Random.new().read(self.batch_size)
        iv_int = int(binascii.hexlify(iv), self.batch_size)
        ctr = Counter.new(self.batch_size * 8, initial_value = iv_int)

        cipher = AES.new(self.key, AES.MODE_CTR, counter = ctr)

        if isinstance(message, bytes):
            message = self.binary_marker + message.hex()
        return base64.b64encode(iv + cipher.encrypt(message.encode()))

    def decrypt(self, ciphertext, decode = True):
        ciphertext = base64.b64decode(ciphertext)
        iv = ciphertext[:self.batch_size]
        ciphertext = ciphertext[self.batch_size:]

        iv_int = int(iv.hex(), self.batch_size)
        ctr = Counter.new(self.batch_size * 8, initial_value = iv_int)

        cipher = AES.new(self.key, AES.MODE_CTR, counter = ctr)
        message = cipher.decrypt(ciphertext)

        if decode:
            message = message.decode("utf-8")
        if isinstance(message, str) and message.startswith(self.binary_marker):
            message = bytes.fromhex(message[len(self.binary_marker):])

        return message
