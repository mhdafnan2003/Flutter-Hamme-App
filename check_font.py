import struct
import os

def read_font_name(path):
    with open(path, 'rb') as f:
        scalar_type = struct.unpack('>I', f.read(4))[0]
        num_tables = struct.unpack('>H', f.read(2))[0]
        f.read(6)
        
        name_offset = 0
        for _ in range(num_tables):
            tag = f.read(4).decode('ascii')
            f.read(4)
            offset = struct.unpack('>I', f.read(4))[0]
            length = struct.unpack('>I', f.read(4))[0]
            if tag == 'name':
                name_offset = offset
                break
        
        if name_offset == 0:
            return {'error': 'name table not found'}
        
        f.seek(name_offset)
        format_selector = struct.unpack('>H', f.read(2))[0]
        count = struct.unpack('>H', f.read(2))[0]
        string_offset = struct.unpack('>H', f.read(2))[0]
        
        names = {}
        for _ in range(count):
            platform_id = struct.unpack('>H', f.read(2))[0]
            encoding_id = struct.unpack('>H', f.read(2))[0]
            language_id = struct.unpack('>H', f.read(2))[0]
            name_id = struct.unpack('>H', f.read(2))[0]
            length = struct.unpack('>H', f.read(2))[0]
            offset = struct.unpack('>H', f.read(2))[0]
            
            if name_id in (1, 2, 4, 16, 17) and platform_id == 3:
                pos = f.tell()
                f.seek(name_offset + string_offset + offset)
                raw = f.read(length)
                try:
                    name = raw.decode('utf-16-be')
                except:
                    name = repr(raw)
                names[name_id] = name
                f.seek(pos)
        
        return names

fonts_dir = '/Users/ihub/Desktop/Zenorix/Works/Flutter-Hamme-App/assets/fonts'
for fname in sorted(os.listdir(fonts_dir)):
    if fname.endswith('.ttf'):
        path = os.path.join(fonts_dir, fname)
        names = read_font_name(path)
        print(f"{fname}: family(1)='{names.get(1, '?')}' style(2)='{names.get(2, '?')}' full(4)='{names.get(4, '?')}' typographic_family(16)='{names.get(16, '?')}' typographic_subfamily(17)='{names.get(17, '?')}'")
