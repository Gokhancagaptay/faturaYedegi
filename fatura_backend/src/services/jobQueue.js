// src/services/jobQueue.js
// Basit in-memory job kuyruğu. Üretim için BullMQ/Cloud Tasks önerilir.

class JobQueue {
    constructor(options = {}) {
        this.queue = [];
        this.isProcessing = false;
        this.maxRetries = options.maxRetries ?? 1;
        this.backoffMs = options.backoffMs ?? 1000;
    }

    add(job) {
        // job: { name, payload, handler }
        this.queue.push({ ...job, attempts: 0 });
        this._maybeProcess();
    }

    _maybeProcess() {
        if (this.isProcessing) return;
        if (this.queue.length === 0) return;
        this.isProcessing = true;
        this._processNext();
    }

    async _processNext() {
        const job = this.queue.shift();
        if (!job) {
            this.isProcessing = false;
            return;
        }
        try {
            await job.handler(job.payload);
        } catch (err) {
            job.attempts += 1;
            if (job.attempts <= this.maxRetries) {
                // backoff ile yeniden sıraya al
                setTimeout(() => this.add(job), this.backoffMs);
            } else {
                // discard; handler içinde hata kaydı yapılmış olmalı
                // burada sadece kuyruğa devam edilir
            }
        } finally {
            this.isProcessing = false;
            // sıradaki işe geç
            setImmediate(() => this._maybeProcess());
        }
    }
}

const defaultQueue = new JobQueue({ maxRetries: 1, backoffMs: 1500 });

module.exports = {
    JobQueue,
    defaultQueue,
};
