/**
 * 文件操作模块
 */
import fs from '@ohos.file.fs';
import { ReadOptions, WriteOptions } from '@kit.CoreFileKit';
import { ProgressRecord, SegmentStat } from './types';

const TAG = 'M3U8Downloader, FileManager';

export class FileManager {

  /**
   * 确保目录存在（递归创建多级目录）
   */
  static async ensureDir(dirPath: string): Promise<void> {
    if (!dirPath || dirPath.length === 0) {
      return;
    }
    // 标准化，避免重复斜杠
    const parts: string[] = dirPath.split('/').filter(p => p.length > 0);
    let current = dirPath.startsWith('/') ? '/' : '';
    for (let i = 0; i < parts.length; i++) {
      current += (current.endsWith('/') ? '' : '/') + parts[i];
      try {
        const exists = fs.accessSync(current);
        if (!exists) {
          await fs.mkdir(current);
        }
      } catch (_) {
        // 不存在则创建
        try {
          await fs.mkdir(current);
        } catch (__){ /* 可能并发创建或已存在 */ }
      }
    }
  }

  /**
   * 同步写入文件
   */
  static async writeFile(filePath: string, data: Uint8Array): Promise<void> {
    // 写入前确保父目录存在
    const slash = filePath.lastIndexOf('/');
    if (slash > 0) {
      const parent = filePath.substring(0, slash);
      await FileManager.ensureDir(parent);
    }
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

  /**
   * 进度记录文件路径
   */
  private static progressFilePath(dir: string): string {
    return `${dir}/progress.json`;
  }

  /**
   * 保存进度（覆盖）
   */
  static async saveProgress(dir: string, record: ProgressRecord): Promise<void> {
    try {
      const content = JSON.stringify(record);
      const data = FileManager.stringToUint8(content);
      await FileManager.writeFile(FileManager.progressFilePath(dir), data);
      console.log(TAG, `进度保存 completed=${record.completed.length}/${record.total}`);
    } catch (e) {
      console.error(TAG, `保存进度失败:`, e);
    }
  }

  /**
   * 字符串转Uint8Array（UTF-8）
   */
  private static stringToUint8(str: string): Uint8Array {
    const utf8: number[] = [];
    for (let i = 0; i < str.length; i++) {
      let charCode = str.charCodeAt(i);
      if (charCode < 0x80) {
        utf8.push(charCode);
      } else if (charCode < 0x800) {
        utf8.push(0xc0 | (charCode >> 6));
        utf8.push(0x80 | (charCode & 0x3f));
      } else if (charCode < 0x10000) {
        utf8.push(0xe0 | (charCode >> 12));
        utf8.push(0x80 | ((charCode >> 6) & 0x3f));
        utf8.push(0x80 | (charCode & 0x3f));
      } else {
        utf8.push(0xf0 | (charCode >> 18));
        utf8.push(0x80 | ((charCode >> 12) & 0x3f));
        utf8.push(0x80 | ((charCode >> 6) & 0x3f));
        utf8.push(0x80 | (charCode & 0x3f));
      }
    }
    return new Uint8Array(utf8);
  }

  /**
   * Uint8Array转字符串（UTF-8）
   */
  private static uint8ToString(arr: ArrayBuffer): string {
    const bytes = new Uint8Array(arr);
    const codePoints: number[] = [];
    for (let i = 0; i < bytes.length; ) {
      const b1 = bytes[i++];
      if (b1 < 0x80) {
        codePoints.push(b1);
      } else if (b1 < 0xe0) {
        const b2 = bytes[i++];
        codePoints.push(((b1 & 0x1f) << 6) | (b2 & 0x3f));
      } else if (b1 < 0xf0) {
        const b2 = bytes[i++], b3 = bytes[i++];
        codePoints.push(((b1 & 0x0f) << 12) | ((b2 & 0x3f) << 6) | (b3 & 0x3f));
      } else {
        const b2 = bytes[i++], b3 = bytes[i++], b4 = bytes[i++];
        let cp = ((b1 & 0x07) << 18) | ((b2 & 0x3f) << 12) | ((b3 & 0x3f) << 6) | (b4 & 0x3f);
        cp -= 0x10000;
        codePoints.push(0xd800 + ((cp >> 10) & 0x3ff));
        codePoints.push(0xdc00 + (cp & 0x3ff));
      }
    }
    return String.fromCharCode(...codePoints);
  }

  /**
   * 追加单个已完成片段到进度
   */
  static async appendProgress(dir: string, index: number, total: number): Promise<void> {
    const current: ProgressRecord | null = await FileManager.loadProgress(dir);
    const set = new Set<number>(current ? current.completed : []);
    set.add(index);
    const record: ProgressRecord = {
      total: total,
      completed: Array.from(set).sort((a, b) => a - b)
    };
    await FileManager.saveProgress(dir, record);
  }

  /**
   * 读取进度
   */
  static async loadProgress(dir: string): Promise<ProgressRecord | null> {
    try {
      const path = FileManager.progressFilePath(dir);
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      try {
        const stat = fs.statSync(path);
        const buf = new ArrayBuffer(stat.size);
        const readOptions: ReadOptions = { offset: 0, length: stat.size };
        fs.readSync(file.fd, buf, readOptions);
        const text = FileManager.uint8ToString(buf);
        const json: ProgressRecord = JSON.parse(text) as ProgressRecord;
        console.log(TAG, `进度读取 completed=${json.completed.length}/${json.total}`);
        return json;
      } finally {
        fs.closeSync(file);
      }
    } catch (_) {
      return null;
    }
  }

  /**
   * 列出已存在的片段索引与大小
   */
  static listExistingSegments(dir: string, total: number): SegmentStat[] {
    const result: SegmentStat[] = [];
    for (let i = 0; i < total; i++) {
      const p = `${dir}segment_${i}.ts`;
      try {
        if (fs.accessSync(p)) {
          const stat = fs.statSync(p);
          if (stat.size > 0) {
            const item: SegmentStat = { index: i, size: stat.size };
            result.push(item);
          }
        }
      } catch (_) {}
    }
    console.log(TAG, `已存在片段: ${result.length}/${total}`);
    return result;
  }

  /**
   * 删除目录（递归）
   */
  static async deleteDirRecursive(dir: string): Promise<void> {
    try {
      // 简单遍历删除文件后删除目录
      for (let i = 0; i < 100000; i++) {
        const p = `${dir}segment_${i}.ts`;
        try {
          if (fs.accessSync(p)) {
            await fs.unlink(p);
          }
        } catch (_) {}
      }
      // 删除进度文件
      try {
        await fs.unlink(FileManager.progressFilePath(dir));
      } catch (_) {}

      try {
        await fs.rmdir(dir);
      } catch (e) {
        console.warn(TAG, `删除目录失败或目录非空: ${dir}`, e);
      }
    } catch (e) {
      console.error(TAG, `递归删除目录失败:`, e);
    }
  }
}