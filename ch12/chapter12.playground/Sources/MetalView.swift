
import MetalKit

public class MetalView: MTKView, NSWindowDelegate {
    
    var queue: MTLCommandQueue! = nil
    var cps: MTLComputePipelineState! = nil
    var timer: Float = 0
    var timerBuffer: MTLBuffer!
    var mouseBuffer: MTLBuffer!
    var pos: NSPoint!
    
    override public func mouseDown(_ event: NSEvent) {
        pos = convertToLayer(convert(event.locationInWindow, from: nil))
        let scale = layer!.contentsScale
        pos.x *= scale
        pos.y *= scale
    }
    
    required public init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override public init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        registerShaders()
    }
    
    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if let drawable = currentDrawable {
            let commandBuffer = queue.commandBuffer()
            let commandEncoder = commandBuffer.computeCommandEncoder()
            commandEncoder.setComputePipelineState(cps)
            commandEncoder.setTexture(drawable.texture, at: 0)
            commandEncoder.setBuffer(mouseBuffer, offset: 0, at: 2)
            commandEncoder.setBuffer(timerBuffer, offset: 0, at: 1)
            update()
            let threadGroupCount = MTLSizeMake(8, 8, 1)
            let threadGroups = MTLSizeMake(drawable.texture.width / threadGroupCount.width, drawable.texture.height / threadGroupCount.height, 1)
            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
    }
    
    func update() {
        timer += 0.01
        var bufferPointer = timerBuffer.contents()
        memcpy(bufferPointer, &timer, sizeof(Float.self))
        bufferPointer = mouseBuffer.contents()
        memcpy(bufferPointer, &pos, sizeof(NSPoint.self))
    }
    
    func registerShaders() {
        queue = device!.newCommandQueue()
        let path = Bundle.main.pathForResource("Shaders", ofType: "metal")
        do {
            let input = try String(contentsOfFile: path!, encoding: String.Encoding.utf8)
            let library = try device!.newLibrary(withSource: input, options: nil)
            let kernel = library.newFunction(withName: "compute")!
            cps = try device!.newComputePipelineState(with: kernel)
        } catch let e {
            Swift.print("\(e)")
        }
        timerBuffer = device!.newBuffer(withLength: sizeof(Float.self), options: [])
        mouseBuffer = device!.newBuffer(withLength: sizeof(NSPoint.self), options: [])
    }
}
