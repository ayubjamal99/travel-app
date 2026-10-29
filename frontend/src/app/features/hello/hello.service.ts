import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable, map, timeout } from 'rxjs';

export interface HelloResponse {
  message: string;
}

export const HELLO_TIMEOUT_MS = 10_000;

@Injectable({ providedIn: 'root' })
export class HelloService {
  private readonly http = inject(HttpClient);

  /** Emits the greeting; errors on network failure, non-2xx, invalid body or after 10 s. */
  getGreeting(): Observable<string> {
    return this.http.get<HelloResponse>('/api/v1/hello').pipe(
      timeout(HELLO_TIMEOUT_MS),
      map((body) => {
        if (typeof body?.message !== 'string' || body.message.length === 0) {
          throw new Error('Invalid hello response');
        }
        return body.message;
      }),
    );
  }
}
