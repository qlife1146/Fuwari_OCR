//
//  UserDefaults+ArchiveData.swift
//  Fuwari
//
//  Created by Kengo Yokoyama on 2016/12/24.
//  Copyright © 2016年 AppKnop. All rights reserved.
//

import Cocoa

extension UserDefaults {
    func setArchiveData<T: NSCoding>(_ object: T, forKey key: String) {
      do {
        let data = try NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: false)
        set(data, forKey: key)
      } catch {
        NSLog("Failed to archive object for key \(key): \(error)")
      }
    }
    
    func archiveDataForKey<T: NSCoding>(_: T.Type, key: String) -> T? {
        guard let data = object(forKey: key) as? Data else { return nil }
      do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            let object = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? T
            unarchiver.finishDecoding()
            return object
        } catch {
            NSLog("Failed to unarchive object for key \(key): \(error)")
            return nil
        }
    }
}

