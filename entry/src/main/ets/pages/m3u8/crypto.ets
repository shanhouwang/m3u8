/**
 * AES加密解密模块
 */
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { CryptoJS } from '@ohos/crypto-js';

const TAG = 'M3U8Downloader, CryptoManager';

export class CryptoManager {
  /**
   * AES-128 CBC解密（使用HarmonyOS官方cryptoFramework）
   */
  static async decryptTs(data: Uint8Array, key: Uint8Array, ivHex: string): Promise<Uint8Array> {
    const startTime = Date.now();
    try {
      console.log(TAG, `开始AES-128 CBC解密`);
      
      // 验证密钥长度（AES-128需要16字节）
      if (key.length !== 16) {
        console.error(TAG, `密钥长度无效: ${key.length} 字节，期望16字节`);
        throw new Error('AES-128密钥长度无效');
      }

      // 处理IV
      let ivBytes: Uint8Array;
      if (ivHex && ivHex.startsWith('0x')) {
        ivBytes = CryptoManager.hexToBytes(ivHex.substring(2));
      } else {
        ivBytes = new Uint8Array(16); // 零IV
        console.warn(TAG, `未提供IV，使用零IV`);
      }

      // 使用HarmonyOS官方cryptoFramework进行解密
      const result = await CryptoManager.harmonyOSAesDecrypt(data, key, ivBytes);

      const endTime = Date.now();
      const decryptTime = endTime - startTime;
      console.log(TAG,
        `解密成功: ${data.length} 字节 -> ${result.length} 字节，耗时: ${decryptTime}ms`);
      
      return result;

    } catch (error) {
      const endTime = Date.now();
      const decryptTime = endTime - startTime;
      console.error(TAG, `HarmonyOS解密失败，耗时: ${decryptTime}ms，降级到CryptoJS:`, error);
      
      // 降级到CryptoJS解密
      return await CryptoManager.fallbackCryptoJsDecrypt(data, key, ivHex);
    }
  }

  /**
   * HarmonyOS官方cryptoFramework AES-128 CBC解密
   */
  private static async harmonyOSAesDecrypt(data: Uint8Array, key: Uint8Array, iv: Uint8Array): Promise<Uint8Array> {
    try {
      // 1. 创建对称密钥生成器
      const aesGenerator = cryptoFramework.createSymKeyGenerator('AES128');
      
      // 2. 将密钥数据转换为SymKey
      const keyBlob: cryptoFramework.DataBlob = { data: key };
      const symKey = await aesGenerator.convertKey(keyBlob);
      
      console.log(TAG, `密钥转换成功`);

      // 3. 创建AES-128 CBC解密器
      const cipher = cryptoFramework.createCipher('AES128|CBC|PKCS7');
      
      // 4. 创建CBC模式参数（包含IV）
      const ivBlob: cryptoFramework.DataBlob = { data: iv };
      const cbcParams: cryptoFramework.IvParamsSpec = {
        algName: 'IvParamsSpec',
        iv: ivBlob
      };

      // 5. 初始化解密器
      await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, cbcParams);
      
      console.log(TAG, `解密器初始化成功`);

      // 6. 执行解密
      const encryptedBlob: cryptoFramework.DataBlob = { data: data };
      const decryptedBlob = await cipher.doFinal(encryptedBlob);
      
      console.log(TAG, `HarmonyOS原生解密成功`);
      
      return decryptedBlob.data;

    } catch (error) {
      console.error(TAG, `HarmonyOS原生解密失败:`, error);
      throw new Error(error.message);
    }
  }

  /**
   * 同步版本的HarmonyOS AES解密（性能更好）
   */
  static harmonyOSAesDecryptSync(data: Uint8Array, key: Uint8Array, iv: Uint8Array): Uint8Array {
    try {
      // 1. 创建对称密钥生成器
      const aesGenerator = cryptoFramework.createSymKeyGenerator('AES128');
      
      // 2. 将密钥数据转换为SymKey（同步版本）
      const keyBlob: cryptoFramework.DataBlob = { data: key };
      const symKey = aesGenerator.convertKeySync(keyBlob);
      
      console.log(TAG, `密钥转换成功`);

      // 3. 创建AES-128 CBC解密器
      const cipher = cryptoFramework.createCipher('AES128|CBC|PKCS7');
      
      // 4. 创建CBC模式参数（包含IV）
      const ivBlob: cryptoFramework.DataBlob = { data: iv };
      const cbcParams: cryptoFramework.IvParamsSpec = {
        algName: 'IvParamsSpec',
        iv: ivBlob
      };

      // 5. 初始化解密器（同步版本）
      cipher.initSync(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, cbcParams);
      
      console.log(TAG, `解密器初始化成功`);

      // 6. 执行解密（同步版本）
      const encryptedBlob: cryptoFramework.DataBlob = { data: data };
      const decryptedBlob = cipher.doFinalSync(encryptedBlob);
      
      console.log(TAG, `HarmonyOS同步解密成功`);
      
      return decryptedBlob.data;

    } catch (error) {
      console.error(TAG, `HarmonyOS同步解密失败:`, error);
      throw new Error(error.message);
    }
  }

  /**
   * 降级到CryptoJS解密（备用方案）
   */
  private static async fallbackCryptoJsDecrypt(data: Uint8Array, key: Uint8Array, ivHex: string): Promise<Uint8Array> {
    try {
      console.log(TAG, `使用CryptoJS备用解密`);
      
      // 将Uint8Array转换为CryptoJS的WordArray
      const encryptedData = CryptoJS.lib.WordArray.create(data);
      
      // 处理IV
      let iv: CryptoJS.lib.WordArray;
      if (ivHex && ivHex.startsWith('0x')) {
        const ivBytes = CryptoManager.hexToBytes(ivHex.substring(2));
        iv = CryptoJS.lib.WordArray.create(ivBytes);
      } else {
        iv = CryptoJS.lib.WordArray.create(new Uint8Array(16));
      }

      // 转换密钥
      const keyWordArray = CryptoJS.lib.WordArray.create(key);

      // AES-128 CBC 解密
      const decrypted = CryptoJS.AES.decrypt(
        { ciphertext: encryptedData } as CryptoJS.lib.CipherParams,
        keyWordArray,
        {
          iv: iv,
          mode: CryptoJS.mode.CBC,
          padding: CryptoJS.pad.Pkcs7
        }
      );

      // 转换回Uint8Array
      const decryptedString = decrypted.toString(CryptoJS.enc.Latin1);
      const result = new Uint8Array(decryptedString.length);

      for (let i = 0; i < decryptedString.length; i++) {
        result[i] = decryptedString.charCodeAt(i);
      }

      console.log(TAG, `CryptoJS备用解密成功`);
      return result;

    } catch (error) {
      console.error(TAG, `CryptoJS解密也失败:`, error);
      throw new Error(`所有解密方法都失败: ${error.message}`);
    }
  }

  /**
   * 16进制字符串转字节数组
   */
  private static hexToBytes(hex: string): Uint8Array {
    const bytes = new Uint8Array(hex.length / 2);
    for (let i = 0; i < hex.length; i += 2) {
      bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
    }
    return bytes;
  }
}