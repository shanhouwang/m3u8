/**
 * 并发控制模块
 */

const TAG = 'ConcurrencyManager';

export class ConcurrencyManager {
  /**
   * Promise池：控制并发数量的任务执行器
   */
  static async executeTasksWithConcurrencyLimit(
    tasks: (() => Promise<void>)[],
    concurrencyLimit: number,
    isCanceled: () => boolean
  ): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      let taskIndex = 0;
      let runningCount = 0;
      let completedCount = 0;
      let hasError = false;

      const executeNextTask = async (): Promise<void> => {
        if (hasError || isCanceled()) {
          return;
        }

        const currentTaskIndex = taskIndex++;
        if (currentTaskIndex >= tasks.length) {
          return;
        }

        runningCount++;
        console.log(TAG, `启动任务 ${currentTaskIndex + 1}/${tasks.length}，当前运行中: ${runningCount}`);

        try {
          await tasks[currentTaskIndex]();
          completedCount++;

          console.log(TAG, `任务 ${currentTaskIndex + 1} 完成，已完成: ${completedCount}/${tasks.length}`);

          // 检查是否全部完成
          if (completedCount === tasks.length) {
            resolve();
            return;
          }

          // 继续执行下一个任务
          if (taskIndex < tasks.length) {
            executeNextTask();
          }
        } catch (error) {
          console.error(TAG, `任务 ${currentTaskIndex + 1} 执行失败:`, error);
          hasError = true;
          reject(error);
        } finally {
          runningCount--;
          console.log(TAG, `任务 ${currentTaskIndex + 1} 结束，当前运行中: ${runningCount}`);
        }
      };

      // 启动初始的并发任务
      const initialConcurrency = Math.min(concurrencyLimit, tasks.length);
      console.log(TAG, `启动 ${initialConcurrency} 个并发任务`);

      for (let i = 0; i < initialConcurrency; i++) {
        executeNextTask();
      }
    });
  }
}