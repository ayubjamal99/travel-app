import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  effect,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { HelloService } from './hello.service';

type HelloState = 'loading' | 'success' | 'error';

@Component({
  selector: 'app-hello',
  templateUrl: './hello.component.html',
  styleUrl: './hello.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class HelloComponent {
  private readonly hello = inject(HelloService);

  protected readonly state = signal<HelloState>('loading');
  protected readonly message = signal('');
  private readonly retryButton = viewChild<ElementRef<HTMLButtonElement>>('retryBtn');
  private focusRetryWhenShown = false;

  constructor() {
    effect(() => {
      const button = this.retryButton();
      if (button && this.focusRetryWhenShown) {
        button.nativeElement.focus();
        this.focusRetryWhenShown = false;
      }
    });
    this.load();
  }

  protected retry(): void {
    this.focusRetryWhenShown = true;
    this.load();
  }

  private load(): void {
    this.state.set('loading');
    this.hello.getGreeting().subscribe({
      next: (message) => {
        this.message.set(message);
        this.state.set('success');
        this.focusRetryWhenShown = false;
      },
      error: () => this.state.set('error'),
    });
  }
}
