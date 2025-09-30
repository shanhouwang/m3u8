/**
 * 文件操作模块
 */
import fs from '@ohos.file.fs';
import { ReadOptions, WriteOptions } from '@kit.CoreFileKit';

const TAG = 'FileManager';

export class FileManager {

  /**
   * 确保目录存在
   */
  static async ensureDir(dirPath: string): Promise<void> {
    try {
      await fs.mkdir(dirPath);
    } catch (error) {
      // 目录可能已存在
    }
  }

  /**
   * 同步写入文件
   */
  static async writeFile(filePath: string, data: Uint8Array): Promise<void> {
    // 将Uint8Array转换为ArrayBuffer
    const arrayBuffer = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength);
    // 打开文件（创建+读写模式）
    const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
    try {
      // 写入数据
      const writeOptions: WriteOptions = {
        length: arrayBuffer.byteLength
      };
      const bytesWritten = fs.writeSync(file.fd, arrayBuffer, writeOptions);
      if (bytesWritten !== arrayBuffer.byteLength) {
        const writeErrorMsg = `写入字节数不匹配: 预期 ${arrayBuffer.byteLength}, 实际 ${bytesWritten}`;
        throw new Error(writeErrorMsg);
      }
      console.log(TAG, `文件写入成功: ${bytesWritten} 字节`)
    } catch (e) {
      console.log(TAG, `文件写入失败:`, e)
      throw new Error(e.message);
    } finally {
      // 确保文件描述符被关闭
      fs.closeSync(file);
    }
  }

  /**
   * 合并文件
   */
  static async mergeFiles(filePaths: string[], outputPath: string): Promise<boolean> {
    console.log(TAG, `开始合并 ${filePaths.length} 个文件到: ${outputPath}`);

    let outputFile: fs.File | null = null;
    let successCount = 0;

    try {
      // 检查输入文件
      const existingFiles: string[] = [];
      for (const filePath of filePaths) {
        try {
          const exists = fs.accessSync(filePath);
          if (exists) {
            const stat = fs.statSync(filePath);
            if (stat.size > 0) {
              existingFiles.push(filePath);
              console.log(TAG, `有效文件: ${filePath}, 大小: ${stat.size} 字节`);
            } else {
              console.warn(TAG, `文件大小为0: ${filePath}`);
            }
          }
        } catch (error) {
          console.warn(TAG, `文件不存在或无法访问: ${filePath}`);
        }
      }

      if (existingFiles.length === 0) {
        console.error(TAG, `没有有效的文件可合并`);
        return false;
      }

      // 创建输出文件
      outputFile = fs.openSync(outputPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      console.log(TAG, `输出文件创建成功`);

      const bufSize = 8192;

      for (let i = 0; i < existingFiles.length; i++) {
        const filePath = existingFiles[i];

        try {
          const sourceFile = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
          const fileSize = fs.statSync(filePath).size;

          console.log(TAG, `合并文件 ${i + 1}/${existingFiles.length}: ${filePath}, 大小: ${fileSize} 字节`);

          let offset = 0;
          while (offset < fileSize) {
            const readSize = Math.min(bufSize, fileSize - offset);
            const buffer = new ArrayBuffer(readSize);

            const readOptions: ReadOptions = {
              offset: offset,
              length: readSize
            };

            const bytesRead = fs.readSync(sourceFile.fd, buffer, readOptions);

            if (bytesRead > 0) {
              const writeOptions: WriteOptions = {
                length: bytesRead
              };
              const bytesWritten = fs.writeSync(outputFile.fd, buffer, writeOptions);
              if (bytesWritten !== bytesRead) {
                console.error(TAG, `写入字节数不匹配: 预期 ${bytesRead}, 实际 ${bytesWritten}`);
              }
              offset += bytesRead;
            } else {
              break;
            }
          }

          fs.closeSync(sourceFile);
          successCount++;

        } catch (error) {
          console.error(TAG, `合并文件失败 ${filePath}:`, error);
        }
      }

      console.log(TAG, `合并完成: ${successCount}/${existingFiles.length} 个文件成功`);
      return successCount > 0;

    } catch (error) {
      console.error(TAG, `合并过程失败:`, error);
      return false;
    } finally {
      if (outputFile) {
        fs.closeSync(outputFile);
      }

      // 验证最终文件
      try {
        const finalStat = fs.statSync(outputPath);
        console.log(TAG, `最终文件大小: ${finalStat.size} 字节`);
      } catch (error) {
        console.error(TAG, `无法获取最终文件信息:`, error);
      }
    }
  }

  /**
   * 清理临时文件
   */
  static async cleanupTempFiles(filePaths: string[]): Promise<void> {
    for (const filePath of filePaths) {
      try {
        await fs.unlink(filePath);
      } catch (error) {
        console.error(TAG, `删除临时文件失败:`, error);
      }
    }
  }
}