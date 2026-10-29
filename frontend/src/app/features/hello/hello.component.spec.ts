import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { HelloComponent } from './hello.component';

describe('HelloComponent', () => {
  let http: HttpTestingController;

  function setup() {
    TestBed.configureTestingModule({
      imports: [HelloComponent],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    http = TestBed.inject(HttpTestingController);
    const fixture = TestBed.createComponent(HelloComponent);
    fixture.detectChanges();
    const el = fixture.nativeElement as HTMLElement;
    const q = (id: string) => el.querySelector(`[data-testid="${id}"]`);
    return { fixture, q };
  }

  afterEach(() => http.verify());

  it('shows loading first', () => {
    const { q } = setup();
    expect(q('hello-loading')).not.toBeNull();
    expect(q('hello-message')).toBeNull();
    http.expectOne('/api/v1/hello');
  });

  it('AC4: shows the greeting in hello-message', async () => {
    const { fixture, q } = setup();
    http.expectOne('/api/v1/hello').flush({ message: 'Hello, traveller!' });
    await fixture.whenStable();
    fixture.detectChanges();
    expect(q('hello-message')?.textContent).toContain('Hello, traveller!');
    expect(q('hello-loading')).toBeNull();
    expect(q('hello-error')).toBeNull();
  });

  it('AC5: shows hello-error with Retry when backend is down, and retry recovers', async () => {
    const { fixture, q } = setup();
    http.expectOne('/api/v1/hello').error(new ProgressEvent('error'));
    await fixture.whenStable();
    fixture.detectChanges();
    expect(q('hello-error')).not.toBeNull();
    expect(q('hello-message')).toBeNull();
    const retry = q('hello-retry') as HTMLButtonElement;
    expect(retry.textContent).toContain('Retry');

    retry.click();
    fixture.detectChanges();
    expect(q('hello-loading')).not.toBeNull();
    http.expectOne('/api/v1/hello').flush({ message: 'Back again' });
    await fixture.whenStable();
    fixture.detectChanges();
    expect(q('hello-message')?.textContent).toContain('Back again');
  });

  it('treats an empty message as an error', async () => {
    const { fixture, q } = setup();
    http.expectOne('/api/v1/hello').flush({ message: '' });
    await fixture.whenStable();
    fixture.detectChanges();
    expect(q('hello-error')).not.toBeNull();
  });
});
