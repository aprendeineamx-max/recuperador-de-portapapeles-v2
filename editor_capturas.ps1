<#
.SYNOPSIS
    Herramienta de Recortes Avanzada (GUI)
    Hotkey: Win + Ctrl + PrintScreen
    Funcionalidad: Seleccionar área -> Auto-guardar y Copiar al Portapapeles.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$saveDir = Join-Path $PSScriptRoot "recortes"
if (-not (Test-Path $saveDir)) {
    New-Item -ItemType Directory -Path $saveDir | Out-Null
}

$startScript = @"
using System;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.IO;
using System.Threading;

public class ScreenCutter : Form
{
    // P/Invoke for Hotkeys
    [DllImport("user32.dll")]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    
    // Constants
    private const int HOTKEY_ID = 9000;
    private const uint MOD_CONTROL = 0x0002;
    private const uint MOD_WIN = 0x0008;
    private const uint VK_SNAPSHOT = 0x2C; // PrintScreen

    // GUI State
    private Point startPoint;
    private Rectangle selectionRect;
    private bool isSelecting = false;
    private Bitmap originalScreen;
    // Removed btnSave as requested (Auto-save)
// Button removed
    private string savePath;
    
    // Message Window for Hotkey
    private NativeWindow msgWindow;

    public ScreenCutter(string path)
    {
        this.savePath = path;
        
        this.ShowInTaskbar = false;
        this.WindowState = FormWindowState.Minimized;
        this.FormBorderStyle = FormBorderStyle.None;
        
        msgWindow = new MessageWindow(this);
        
        if (!RegisterHotKey(msgWindow.Handle, HOTKEY_ID, MOD_CONTROL | MOD_WIN, VK_SNAPSHOT))
        {
            // Fail silently or log
        }
        
        InitializeOverlay();
        this.KeyPreview = true;
    }

    private void InitializeOverlay()
    {
        this.DoubleBuffered = true;
        this.TopMost = true;
        this.Cursor = Cursors.Cross;
        
        this.DoubleBuffered = true;
        this.TopMost = true;
        this.Cursor = Cursors.Cross;
        
        // Button removed as requested to rely entirely on ESC key
    }
    
    public void ActivateCapture()
    {
        Rectangle bounds = Screen.PrimaryScreen.Bounds;
        originalScreen = new Bitmap(bounds.Width, bounds.Height);
        using (Graphics g = Graphics.FromImage(originalScreen))
        {
            g.CopyFromScreen(Point.Empty, Point.Empty, bounds.Size);
        }

        this.BackgroundImage = originalScreen;
        this.Size = bounds.Size;
        this.Location = Point.Empty;
        this.WindowState = FormWindowState.Maximized;
        this.FormBorderStyle = FormBorderStyle.None;
        this.Visible = true;
        this.Show();
        this.Activate();
        
        // Button visibility logic removed
        selectionRect = Rectangle.Empty;
        isSelecting = false; // Reset state ensures fresh start
    }

    private void DeactivateOverlay()
    {
        isSelecting = false; // Critical: Prevent OnMouseUp from saving if Esc was pressed
        this.Hide();
        if (this.BackgroundImage != null) this.BackgroundImage.Dispose();
        this.BackgroundImage = null;
        selectionRect = Rectangle.Empty;
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        if (e.Button == MouseButtons.Left)
        {
            isSelecting = true;
            startPoint = e.Location;
            selectionRect = Rectangle.Empty;
            this.Invalidate();
        }
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        if (isSelecting)
        {
            int x = Math.Min(startPoint.X, e.X);
            int y = Math.Min(startPoint.Y, e.Y);
            int width = Math.Abs(startPoint.X - e.X);
            int height = Math.Abs(startPoint.Y - e.Y);
            selectionRect = new Rectangle(x, y, width, height);
            this.Invalidate();
        }
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        if (isSelecting)
        {
            isSelecting = false;
            if (selectionRect.Width > 10 && selectionRect.Height > 10) // Min size check
            {
                SaveAndCopySelection();
            }
        }
    }

    private void SaveAndCopySelection()
    {
        try
        {
            Bitmap crop = new Bitmap(selectionRect.Width, selectionRect.Height);
            using (Graphics g = Graphics.FromImage(crop))
            {
                g.DrawImage(originalScreen, new Rectangle(0, 0, crop.Width, crop.Height), selectionRect, GraphicsUnit.Pixel);
            }

            // 1. Save to File
            string timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
            string filename = "recorte_" + timestamp + ".png";
            string fullPath = Path.Combine(savePath, filename);
            crop.Save(fullPath, System.Drawing.Imaging.ImageFormat.Png);

            // 2. Copy to Clipboard with Marker
            DataObject data = new DataObject();
            data.SetImage(crop);
            data.SetData("RecorteMarker", "true");
            Clipboard.SetDataObject(data, true);
            
            crop.Dispose();
            
            // Close Overlay immediately
            DeactivateOverlay();
        }
        catch (Exception ex)
        {
            MessageBox.Show("Error: " + ex.Message);
            DeactivateOverlay();
        }
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        using (Brush brush = new SolidBrush(Color.FromArgb(100, 0, 0, 0)))
        {
            Region region = new Region(new Rectangle(0, 0, this.Width, this.Height));
            if (selectionRect.Width > 0 && selectionRect.Height > 0)
            {
                region.Exclude(selectionRect);
            }
            e.Graphics.FillRegion(brush, region);
        }

        if (selectionRect.Width > 0)
        {
            using (Pen pen = new Pen(Color.Red, 2))
            {
                e.Graphics.DrawRectangle(pen, selectionRect);
            }
        }
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Escape)
        {
            DeactivateOverlay();
        }
    }
    
    private class MessageWindow : NativeWindow
    {
        private ScreenCutter parent;
        private const int WM_HOTKEY = 0x0312;

        public MessageWindow(ScreenCutter parent)
        {
            this.parent = parent;
            this.CreateHandle(new CreateParams());
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == WM_HOTKEY)
            {
                if (m.WParam.ToInt32() == 9000)
                {
                    parent.ActivateCapture();
                }
            }
            base.WndProc(ref m);
        }
    }
}
"@

Add-Type -TypeDefinition $startScript -ReferencedAssemblies System.Windows.Forms, System.Drawing

Write-Host "Iniciando Herramienta de Recortes (Auto-Save)..." -ForegroundColor Cyan
Write-Host "Hotkey Global: Win + Ctrl + ImpPant (PrintScreen)" -ForegroundColor Green

# Use single thread apartment state
$form = New-Object ScreenCutter -ArgumentList $saveDir
[System.Windows.Forms.Application]::Run($form)
